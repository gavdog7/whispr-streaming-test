# Whisper Streaming Benchmark Analysis

**Date:** 2026-01-07
**Hardware:** MacBook Pro M1 Max, 64GB RAM
**Conclusion:** No Whisper model is fully viable for real-time streaming on this hardware

---

## Executive Summary

Testing all five Whisper models (tiny through large-v3) revealed a fundamental tradeoff between **transcription accuracy** and **processing speed**. The smaller models (tiny, base) can process audio faster than realtime but produce poor quality transcriptions with frequent errors. The larger models (medium, large-v3) produce excellent transcriptions but cannot keep pace with realtime audio input.

**Key Finding:** There is no "sweet spot" model that provides both acceptable accuracy AND realtime processing capability using the cumulative buffer approach on Apple Silicon.

---

## The Speed vs. Quality Tradeoff

```
                    PROCESSING SPEED
        Fast ◄────────────────────────────► Slow

    tiny ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 0.28x ✓
    base ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 0.34x ✓
   small ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 1.76x ✗
  medium ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 15.91x ✗
 large-v3 ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 55.61x ✗

        ▲ 1.0x threshold (realtime)

                    TRANSCRIPTION QUALITY
        Poor ◄────────────────────────────► Excellent

    tiny ●━━━━━━━━━━━━━━━━━━━━━ 2/5 (word duplications, hallucinations)
    base ●━━━━━━━━━━━━━━━━━━━━━ 2/5 (hallucinations: "gruesome stuff")
   small ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 3/5 (better accuracy, truncated)
  medium ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 4/5 (near-perfect where captured)
 large-v3 ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 5/5* (excellent, but unusable)

        * Quality rating 1/5 due to streaming failure, not transcription accuracy
```

---

## Detailed Analysis by Model

### Tier 1: Fast but Inaccurate (tiny, base)

| Model | Ratio | Quality | Viable? |
|-------|-------|---------|---------|
| tiny | 0.28x | 2/5 | Marginal |
| base | 0.34x | 2/5 | Marginal |

**Strengths:**
- Process audio 3-4x faster than realtime
- Zero backpressure events
- Run entirely on Apple Neural Engine (ANE)
- Low latency to first word (~4.4s)

**Weaknesses:**
- Frequent word duplications ("at this at this", "soup, soup")
- Hallucinations ("gruesome stuff" instead of "croissants")
- Missing large portions of speech
- Broken sentence structures

**Assessment:** These models can keep up with realtime audio but the transcription quality is too poor for practical use. The output requires significant mental effort to parse and would be unsuitable for dictation, captioning, or accessibility applications.

---

### Tier 2: The Cliff (small)

| Model | Ratio | Quality | Viable? |
|-------|-------|---------|---------|
| small | 1.76x | 3/5 | No |

**Strengths:**
- Slightly better accuracy than tiny/base
- Still runs on ANE
- Moderate improvement in word recognition

**Weaknesses:**
- **Crossed the 1.0x threshold** - cannot keep up with realtime
- 8 backpressure events during 35-second test
- Audio accumulates faster than it can be processed
- Output becomes increasingly delayed and truncated

**Assessment:** The small model represents a critical threshold. At 1.76x realtime, it falls behind by ~27 seconds over a 35-second recording. This makes it unsuitable for streaming despite moderate quality improvements.

---

### Tier 3: High Quality but Unusable (medium, large-v3)

| Model | Ratio | Quality | Viable? |
|-------|-------|---------|---------|
| medium | 15.91x | 4/5 | No |
| large-v3 | 55.61x | 5/5* | No |

**Strengths:**
- Excellent transcription accuracy where captured
- medium model was nearly word-perfect
- large-v3 handled punctuation and grammar elegantly
- Better handling of natural speech patterns

**Weaknesses:**
- **Catastrophically slow** for streaming
- medium: 1 second of audio takes 16 seconds to process
- large-v3: 1 second of audio takes 56 seconds to process
- Switched from ANE to GPU (less efficient on Apple Silicon)
- Massive latency (8.7s for medium, 38.3s for large-v3)
- large-v3 threw ML Program errors during processing

**Assessment:** These models produce excellent transcriptions but are fundamentally incompatible with streaming. The large-v3 model didn't even display its first word until after the entire 35-second recording completed. They should only be used for batch/offline transcription.

---

## Root Cause Analysis

### Why the Cumulative Buffer Approach Fails

The benchmark uses a cumulative buffer strategy where all audio is accumulated and re-transcribed on each update. This approach has a fundamental flaw:

```
Time 0s:   Transcribe 1.5s of audio    → Fast
Time 3s:   Transcribe 4.5s of audio    → Moderate
Time 10s:  Transcribe 11.5s of audio   → Slow
Time 30s:  Transcribe 30s of audio     → Very Slow (capped)
```

As audio accumulates, each transcription takes longer. Even with a 30-second cap, the larger models cannot process 30 seconds of audio in less than 30 seconds.

### ANE vs GPU Execution

| Model | Compute Unit | Efficiency |
|-------|--------------|------------|
| tiny | ANE | High |
| base | ANE | High |
| small | ANE | Moderate |
| medium | GPU | Low |
| large-v3 | GPU | Very Low |

Apple's Neural Engine (ANE) is optimized for ML inference but has memory constraints. The medium and large-v3 models exceed these constraints and fall back to GPU execution, which is significantly slower for this workload.

### The 4.4s Latency Floor

Even the fastest models (tiny, base) have ~4.4 second latency to first word. This suggests:
1. Initial model inference has fixed overhead
2. The cumulative buffer needs minimum audio (~1-1.5s) before first transcription
3. WhisperKit initialization adds latency on first inference

---

## Comparison to Success Criteria

The benchmark defined streaming viability as:
- Processing ratio < 1.0x realtime ✓ (tiny, base only)
- First-word latency < 3.0 seconds ✗ (no model achieved this)
- Zero backpressure events ✓ (tiny, base only)
- User confirms transcription is readable ✗ (no model achieved this)

**No model met all four criteria.**

---

## Recommendations

### For This Hardware (M1 Max, 64GB)

1. **Don't use Whisper for live streaming transcription** - The technology isn't ready for this use case with the cumulative buffer approach.

2. **For near-realtime needs:** Use tiny or base with post-processing
   - Accept 4-5 second latency
   - Implement error correction in post-processing
   - Consider it "live with delay" not "realtime"

3. **For quality transcription:** Use medium or large-v3 in batch mode
   - Record complete audio first
   - Transcribe after recording ends
   - Excellent accuracy when time isn't constrained

### Alternative Approaches to Explore

1. **Streaming-optimized models:** Distil-Whisper or other models designed for streaming may perform better than standard Whisper models.

2. **Chunk-based transcription:** Instead of cumulative buffer, process independent chunks and stitch results. May reduce accuracy but could enable faster processing.

3. **Hybrid approach:** Use tiny model for live preview, then re-transcribe with larger model for final output.

4. **External services:** Cloud-based streaming transcription (Whisper API, AssemblyAI, Deepgram) may offer better realtime performance.

5. **Different hardware:** Test on M2/M3 Ultra or dedicated ML hardware that may handle larger models more efficiently.

---

## Conclusions

1. **The cumulative buffer approach is fundamentally limited** - Re-transcribing growing audio becomes exponentially expensive.

2. **Model size directly correlates with both quality and latency** - There's no free lunch; better accuracy requires more computation.

3. **Apple Silicon's ANE is efficient but constrained** - Models larger than ~250MB fall back to slower GPU execution.

4. **Live streaming transcription with Whisper requires architectural changes** - The standard transcription API is designed for batch processing, not streaming.

5. **"Marginal" is generous for tiny/base** - While they meet speed requirements, the transcription quality (word duplications, hallucinations) makes them unsuitable for most production use cases.

---

## Next Steps

1. Research WhisperKit's native streaming capabilities (if any)
2. Test distil-whisper models for potentially better speed/quality tradeoff
3. Implement chunk-based approach as alternative to cumulative buffer
4. Consider hybrid live-preview + batch-final architecture
5. Benchmark against cloud streaming services for comparison

---

*This analysis is based on a single test run. Results may vary with different hardware, audio conditions, and speaking patterns.*
