# Issue Diagnosis Report

**Date:** 2026-01-07
**Reporter:** User testing via CLI logs
**Status:** Diagnosis complete, fixes proposed

---

## Summary of Observed Issues

1. **Models appear to download twice** - Pre-download phase shows success, but testing phase says "Model not found locally"
2. **Transcription not accumulating** - Individual words appear but don't build into complete text; final transcript shows mostly `[BLANK_AUDIO]`
3. **Recording control broken** - Enter key doesn't stop recording as advertised; recording auto-stops unexpectedly
4. **Passages too short** - User reports 15 seconds to read, but minimum recording is 20s with target of 30s

---

## Issue 1: Models Downloaded Twice

### Observed Behavior
```
[1/5] ✓ openai_whisper-tiny (downloaded)
...
Testing Model: openai_whisper-tiny (39 MB)
Model 'openai_whisper-tiny' not found locally - will download...
Loading model (downloading if needed)... Done (5.8s)
```

### Root Cause
**File:** `Sources/StreamingBenchmark/LiveTranscriber.swift:46-53`

The `modelExists()` and `availableModels()` functions check for models at:
```swift
~/Library/Caches/com.argmax.whisperkit/{model_name}
```

However, WhisperKit stores downloaded models in a different location - typically:
```
~/Library/Caches/com.argmax.whisperkit/huggingface/models--argmaxinc--whisperkit-coreml/{model_name}
```

The path mismatch means:
- Pre-download phase: `modelExists()` returns false (wrong path), triggers download
- Download succeeds (WhisperKit stores to correct location)
- Test phase: `availableModels()` checks wrong path, returns empty
- Test triggers another download attempt (though WhisperKit likely uses cached files)

### Impact
- Confusing user messaging (says "will download" when already cached)
- Wasted time on redundant model loading operations
- 5.8s load time suggests it's not re-downloading, but re-initializing

### Suggested Fix
Query WhisperKit directly for available/cached models instead of manually checking filesystem paths. WhisperKit may have an API for this, or we should match their actual cache directory structure.

---

## Issue 2: Transcription Not Accumulating (CRITICAL)

### Observed Behavior
```
Live Transcription:
───────────────────────────────────────────────────────────────

[go.]
[BLANK_AUDIO][since we all got together.]
...
Recording... ● [00:35]
[BLANK_AUDIO][[BLANK_AUDIO]]

TRANSCRIPT:
[BLANK_AUDIO] [BLANK_AUDIO]
```

Individual words flash on screen but don't accumulate. Final transcript is mostly `[BLANK_AUDIO]` tokens.

### Root Cause
**File:** `Sources/StreamingBenchmark/LiveTranscriber.swift:84-112`

The fundamental problem is **architectural** - the code treats each audio chunk as an independent transcription:

```swift
func transcribeChunk(_ samples: [Float]) async throws -> TimeInterval {
    // Transcribes ONLY this 1.5-second chunk in isolation
    let results = try await whisper.transcribe(audioArray: samples)
    // ...
}
```

WhisperKit's `transcribe(audioArray:)` is designed for **batch processing** of complete audio files. When given a 1.5-second chunk in isolation:

1. **No audio context** - Whisper needs ~5-10 seconds of audio for accurate transcription. Short chunks produce unreliable results
2. **Each chunk starts fresh** - No continuity between chunks; can't leverage previous context
3. **`[BLANK_AUDIO]` tokens** - Whisper outputs these when audio is too short/unclear for meaningful transcription
4. **LocalAgreement fails** - The confirmation algorithm compares token sequences across chunks, but each chunk produces different (often garbage) results since they're independent

### Why LocalAgreement-N Doesn't Help Here
The LocalAgreement algorithm (lines 148-209) assumes:
- Consecutive chunks transcribe overlapping audio
- Same tokens appear at same positions across multiple chunks

But since each chunk is transcribed independently without overlap context, tokens vary wildly between chunks. The algorithm never confirms anything because nothing matches.

### The Real Streaming Problem
True streaming transcription requires one of:

**Option A: Cumulative Buffer (Simpler)**
- Accumulate ALL audio from recording start
- Re-transcribe the entire buffer on each update
- Display delta between previous and current transcription
- Con: Processing time grows as audio accumulates

**Option B: Sliding Window (Better)**
- Maintain a rolling buffer (e.g., last 15-30 seconds)
- Transcribe the window each time
- Track which words have been "finalized" based on stability
- Con: More complex state management

**Option C: WhisperKit Streaming Mode (If Available)**
- Use WhisperKit's built-in streaming transcription if it has one
- May handle chunking and context internally
- Con: Need to check WhisperKit API documentation

### Impact
- Transcription is essentially non-functional
- Users see gibberish instead of their speech
- Quality ratings will always be "Unusable"

### Suggested Fix
Implement Option A (cumulative buffer) as first step:
1. In `AudioCapture`, maintain a complete buffer alongside chunks
2. In `LiveTranscriber`, transcribe the full accumulated audio (up to ~30s)
3. Compare new transcription to previous, display incremental words
4. For longer recordings, use sliding window approach

---

## Issue 3: Recording Control Broken

### Observed Behavior
User presses Enter expecting to stop recording, but:
- Recording continues
- Something else gets triggered (possibly starts new recording?)
- Recording eventually stops on its own after 35 seconds

### Root Cause
**File:** `Sources/StreamingBenchmark/BenchmarkRunner.swift:231-256`

The code explicitly **does not** listen for Enter key:

```swift
// Recording loop - update display every second
while true {
    try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

    // Check if minimum duration reached and user might want to stop
    if duration >= minimumRecordingDuration {
        // For this implementation, let's auto-stop at ~35 seconds
        // A proper implementation would use non-blocking stdin
        if duration >= 35 {
            break  // ← Only exit condition!
        }
    }
}
```

The UI says "Press ENTER again to stop" but the code:
- Ignores all user input during recording
- Auto-stops unconditionally at 35 seconds
- No actual Enter key detection

When user presses Enter during recording, stdin buffers the input. This buffered Enter may be consumed by the next `readLine()` call (e.g., `waitForReviewComplete()`), causing unexpected behavior.

### Impact
- Misleading instructions frustrate users
- Users can't control recording duration
- Buffered Enter presses cause flow control issues

### Suggested Fix
Implement non-blocking stdin reading or use a different stop mechanism:

**Option A: Background stdin reader**
```swift
let inputTask = Task {
    _ = readLine()  // Blocks until Enter
    return true
}

while !inputTask.isComplete && duration < maxDuration {
    // ... continue recording
}
```

**Option B: Fixed duration with countdown**
- Remove "press Enter to stop" message
- Show clear countdown: "Recording for 30 seconds..."
- Set expectations correctly

---

## Issue 4: Passages Too Short

### Observed Behavior
User reports passages take ~15 seconds to read, but:
- Minimum recording is 20 seconds
- Target recording is 30 seconds
- Results in 5-15 seconds of awkward silence

### Root Cause
**File:** `Sources/StreamingBenchmark/Passages.swift`

Current passages are ~50-60 words each. Example:

```
We're planning a family reunion for next summer. It's been five years since we
all got together. My cousins are flying in from across the country. We rented
a big cabin by the lake. There's going to be so much food and catching up.
I can't wait to see everyone.
```

**Word count:** ~52 words
**At 150 WPM (average):** ~21 seconds
**At 180 WPM (faster reader):** ~17 seconds
**At 200 WPM (fast reader):** ~15 seconds

The comment says "~30-45 seconds each" but that's optimistic. Many people read faster than expected, especially with conversational text.

### Impact
- Users finish reading well before recording stops
- Trailing silence may confuse transcription (more `[BLANK_AUDIO]`)
- Awkward user experience

### Suggested Fix
Double the passage length to ~100-120 words each:

**Example expanded passage:**
```
We're planning a family reunion for next summer. It's been five years since we
all got together, and I've really missed everyone. My cousins are flying in
from across the country - Sarah from Seattle, Mike from Miami, and the twins
from Texas. We rented a big cabin by the lake with enough room for all twenty
of us. There's going to be so much food. Aunt Maria is bringing her famous
lasagna, and Uncle Joe promised to grill burgers. We're planning a bonfire
the first night, and someone suggested we do a talent show like we used to
when we were kids. I've already started practicing my terrible guitar playing.
I can't wait to see everyone and catch up on the last five years.
```

**Word count:** ~130 words
**At 150 WPM:** ~52 seconds
**At 180 WPM:** ~43 seconds
**At 200 WPM:** ~39 seconds

---

## Priority Order for Fixes

| Priority | Issue | Effort | Impact |
|----------|-------|--------|--------|
| 1 | Transcription not accumulating | High | Critical - app is non-functional |
| 2 | Recording control broken | Medium | High - UX is misleading |
| 3 | Passages too short | Low | Medium - suboptimal testing |
| 4 | Models downloaded twice | Low | Low - cosmetic/messaging |

---

## Recommended Path Forward

### Phase 1: Fix Critical Transcription Bug
1. Modify `LiveTranscriber` to accumulate audio into a growing buffer
2. On each new chunk, transcribe the full buffer (capped at ~30s)
3. Implement word-level diffing to show incremental progress
4. Remove LocalAgreement-N (not needed with cumulative approach)

### Phase 2: Fix Recording Controls
1. Either implement actual Enter key detection (background task)
2. Or change UI to show fixed-duration countdown, remove "press Enter" messaging

### Phase 3: Expand Passages
1. Double the word count of each passage
2. Aim for 100-120 words per passage
3. Keep conversational, natural tone

### Phase 4: Fix Model Path Detection
1. Update `modelExists()` to check correct WhisperKit cache location
2. Or remove redundant path checking, rely on WhisperKit's caching

---

## Questions for User Approval

1. **Transcription approach**: Should we go with cumulative buffer (simpler, works up to ~60s) or sliding window (more complex, handles longer recordings)?

2. **Recording control**: Prefer Enter-key detection (more flexible) or fixed countdown (simpler, clearer expectations)?

3. **Passage style**: Keep current conversational passages (just longer) or switch to more formal/technical text?
