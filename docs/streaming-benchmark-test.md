# Streaming Benchmark Test Plan

**Created:** 2026-01-06
**Status:** Draft - Awaiting Approval
**Purpose:** Create a terminal-based tool to benchmark which Whisper models can support live streaming transcription on the current hardware.
**Repository:** Separate repo - `whisper-streaming-benchmark`

---

## Overview

This plan describes a standalone Swift Package command-line tool that tests streaming transcription performance across different Whisper models. The tool will:

1. Start with the smallest model (tiny)
2. Run a warmup inference (discarded from metrics)
3. Prompt the user to speak for ~30 seconds
4. Display words as they appear in real-time
5. Measure and report performance metrics
6. If successful, progress to larger models
7. Output a final report showing which models are viable for streaming

**Key Decisions:**
- **Separate repository** - General-purpose hardware benchmark, not tied to any specific app
- **Swift Package executable** - Build with `swift build`, run from terminal
- **Pre-download required** - Models must be downloaded before running
- **All 5 models** - Test tiny, base, small, medium, and large-v3

---

## Background & Learnings

### Previous Streaming Implementation Issues

From WisprFlow's streaming implementation (`docs/archive/streaming-implementation/05-issue-diagnosis-2026-01-02.md`):

| Model | Processing Ratio | Streaming Viable? |
|-------|------------------|-------------------|
| Tiny | ~0.2-0.3x realtime | Yes |
| Base | ~0.4-0.5x realtime | Yes |
| Small | ~0.5-0.7x realtime | Yes |
| Large | 2.5-3.0x realtime | No |

**Key insight:** For streaming to work, the model must process audio faster than realtime (< 1.0x ratio). The Large model processes 1.5s chunks in 4-12 seconds, causing backpressure and unusable delays.

### WhisperKit Streaming API

WhisperKit supports streaming via callbacks:
- Property: `whisperKit.segmentDiscoveryCallback`
- Callback receives `[TranscriptionSegment]` per audio window
- No `isConfirmed` field - confirmation computed via LocalAgreement-n policy

**API Verification Required:** Before implementation, verify the current WhisperKit version (0.9.x+) still exposes `segmentDiscoveryCallback`. Check the WhisperKit repo and confirm the streaming API shape. If the API has changed, update this plan accordingly.

---

## Design

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    StreamingBenchmark                        │
│                    (Command-line tool)                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   ModelTest  │───►│  AudioCapture │───►│ WhisperKit   │  │
│  │   Runner     │    │  (Microphone) │    │ Streaming    │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                                        │          │
│         │                    ┌───────────────────┘          │
│         │                    ▼                              │
│         │           ┌──────────────────┐                    │
│         └──────────►│  Live Display    │                    │
│                     │  (Terminal)      │                    │
│                     └──────────────────┘                    │
│                              │                              │
│                              ▼                              │
│                     ┌──────────────────┐                    │
│                     │  Results Report  │                    │
│                     └──────────────────┘                    │
└─────────────────────────────────────────────────────────────┘
```

### Test Flow

```
Start
  │
  ▼
┌─────────────────────────────┐
│  1. Load Model              │
│     (smallest first)        │
│     Verify model exists     │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│  2. Warmup Run              │
│     - Short 3s recording    │
│     - Discard results       │
│     - Primes model/caches   │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│  3. Display Instructions    │
│     Show test prompts for   │
│     ~30 seconds of speech   │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│  4. Start Recording         │
│     (Press Enter to start,  │
│      Enter again to stop)   │
│     Minimum: 20 seconds     │
│     Target: 30 seconds      │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│  5. Stream Audio to Model   │
│     - 1.5s chunks, 0.25s    │
│       overlap               │
│     - Display words live    │
│     - Track timing/metrics  │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│  6. Calculate Metrics       │
│     - Processing ratio      │
│     - First-word latency    │
│     - Backpressure count    │
│     - Compute unit (ANE/GPU)│
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│  7. User Quality Assessment │
│     "Was transcription      │
│      readable?" (y/n)       │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│  8. Ask: Continue to next   │
│     model? (y/n)            │
└─────────────────────────────┘
  │
  ├── Yes ──► Next Model ─────┐
  │                           │
  │                           ▼
  └── No ────► Final Report ──┴──► End
```

### Models to Test (in order)

1. **openai_whisper-tiny** (~39MB) - Fastest, least accurate
2. **openai_whisper-base** (~74MB) - Good balance for streaming
3. **openai_whisper-small** (~244MB) - Better accuracy
4. **openai_whisper-medium** (~769MB) - High accuracy, may be marginal for streaming
5. **openai_whisper-large-v3** (~1.5GB) - Highest accuracy, likely too slow for streaming

### Streaming Configuration

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Chunk Duration | 1.5 seconds | Balance between latency and context |
| Chunk Overlap | 0.25 seconds | Prevents word splits at boundaries |
| Sample Rate | 16kHz | WhisperKit requirement |
| LocalAgreement-n | n=2 | Last 2 tokens held as unconfirmed |
| Confirmation Window | 3 consecutive chunks | Token confirmed after appearing in 3 chunks |

**LocalAgreement-2 Policy:** Tokens are considered "confirmed" when they appear consistently across 3 consecutive chunk transcriptions. The last 2 tokens of the current transcription are always displayed as "unconfirmed" (dimmed) since they may change with more audio context.

### Metrics Captured

| Metric | Description | Target for Streaming |
|--------|-------------|---------------------|
| Processing Ratio | time_to_process / audio_duration | < 1.0x |
| First-Word Latency | Time from recording start to first text appearing | < 2.0s |
| Chunk Latency | Average time to process each 1.5s chunk | < 1.5s |
| Backpressure Events | Chunks where processing exceeded chunk duration | 0 |
| Compute Unit | ANE (Neural Engine) or GPU | Informational |
| Transcription Quality | Subjective user assessment | Usable |

**First-Word Latency Definition:** Measured from when audio recording begins (user presses Enter) to when the first transcribed token appears on screen. This includes the initial 1.5s chunk accumulation time plus processing time.

**Backpressure Definition:** A backpressure event occurs when chunk N+1 is ready but chunk N is still processing. With a 1.5s chunk duration, any chunk taking >1.5s to process causes backpressure. The queue holds at most 2 pending chunks; additional chunks are dropped with a warning.

### Success Criteria

A model is considered **streaming-viable** if:
- Processing ratio < 1.0x realtime
- First-word latency < 3.0 seconds
- Zero backpressure events during 30-second test
- User confirms transcription is readable

---

## Implementation

### Repository Structure

```
whisper-streaming-benchmark/
├── Package.swift                    # Swift Package manifest
├── README.md                        # Setup and usage instructions
├── .gitignore
└── Sources/
    └── StreamingBenchmark/
        ├── main.swift               # Entry point, ArgumentParser command
        ├── BenchmarkRunner.swift    # Test orchestration, model progression
        ├── LiveTranscriber.swift    # WhisperKit streaming wrapper
        ├── AudioCapture.swift       # Microphone input (AVFoundation)
        ├── TerminalDisplay.swift    # Real-time ANSI terminal output
        ├── Metrics.swift            # Timing and metrics collection
        ├── ComputeInfo.swift        # ANE/GPU detection
        └── ResultsReporter.swift    # Final summary and JSON export

Results are saved to `~/Documents/whisper-streaming-benchmark-<date>.json` by default (configurable via `--output`).
```

### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "whisper-streaming-benchmark",
    platforms: [
        .macOS(.v14)  // Requires Sonoma+ for latest WhisperKit optimizations
    ],
    products: [
        .executable(name: "streaming-benchmark", targets: ["StreamingBenchmark"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "StreamingBenchmark",
            dependencies: [
                "WhisperKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
```

**Platform Rationale:** macOS 14 (Sonoma) is required because:
- WhisperKit optimizations for Apple Silicon are best on latest OS
- Neural Engine scheduling improvements in Sonoma
- Swift concurrency features used by WhisperKit

**CLI Flags (via ArgumentParser):**
- `--model <name>` - Test only a specific model
- `--skip-warmup` - Skip warmup phase (for debugging)
- `--output <path>` - Custom JSON output path
- `--verbose` - Show detailed timing for each chunk

### Build & Run

```bash
# Clone the repo
git clone https://github.com/[user]/whisper-streaming-benchmark.git
cd whisper-streaming-benchmark

# Build
swift build -c release

# Run
.build/release/streaming-benchmark
```

---

## Implementation Phases

### Phase 1: Basic Infrastructure

1. **Create repo and Package.swift**
   - Initialize Swift Package
   - Add WhisperKit dependency
   - Verify builds

2. **Implement basic audio capture**
   - Use AVFoundation for microphone access
   - 16kHz sample rate (WhisperKit requirement)
   - Simple start/stop triggered by Enter key

3. **Implement terminal display**
   - ANSI escape codes for cursor control
   - Clear and redraw for smooth updates
   - Show current transcription with timing

### Phase 2: Streaming Integration

1. **Implement WhisperKit streaming wrapper**
   - Configure `segmentDiscoveryCallback`
   - Chunk audio at 1.5s intervals
   - Track processing times per chunk

2. **Implement LocalAgreement-n confirmation**
   - Keep last 2 segments as "unconfirmed"
   - Display confirmed text normally
   - Display unconfirmed text in gray/dim

### Phase 3: Benchmark Logic

1. **Implement model progression**
   - Start with tiny, work up to large
   - Verify model exists before testing (pre-download required)
   - Ask user before progressing to next model

2. **Implement metrics collection**
   - Track all timing information
   - Calculate processing ratios
   - Count backpressure events

3. **Implement results report**
   - Summary table of all tested models
   - Recommendation for which models are streaming-viable
   - Save results to JSON for later analysis

---

## Example Terminal Output

```
═══════════════════════════════════════════════════════════════
           Whisper Streaming Benchmark
═══════════════════════════════════════════════════════════════

Testing Model: openai_whisper-tiny (39 MB)
Loading model... Done (2.3s)

Running warmup (3 seconds)... Done

───────────────────────────────────────────────────────────────
Instructions - Please read aloud for ~30 seconds:
───────────────────────────────────────────────────────────────

  "The quick brown fox jumps over the lazy dog. Pack my box
   with five dozen liquor jugs. How vexingly quick daft
   zebras jump. The five boxing wizards jump quickly.
   Sphinx of black quartz, judge my vow. Two driven jocks
   help fax my big quiz. The jay, pig, fox, zebra, and my
   wolves quack. Sympathizing would fix Quaker objectives."

Press ENTER to start recording (minimum 20s, target 30s).
Press ENTER again to stop.

Recording... ● [00:24]

───────────────────────────────────────────────────────────────
Live Transcription:
───────────────────────────────────────────────────────────────

The quick brown fox jumps over the lazy dog. Pack my box
with five dozen liquor jugs. How vexingly quick daft zebras [jump]

(Words in [brackets] are unconfirmed - may change)

───────────────────────────────────────────────────────────────
Timing (live):
  Chunk 1: 1.5s audio → 0.41s process (0.27x) ✓
  Chunk 2: 1.5s audio → 0.48s process (0.32x) ✓
  Chunk 3: 1.5s audio → 0.39s process (0.26x) ✓
  ...
  Chunk 16: 1.5s audio → 0.44s process (0.29x) ✓
───────────────────────────────────────────────────────────────

Recording stopped. Duration: 24.3 seconds

Was the transcription readable and usable? [Y/n]: y

Results for openai_whisper-tiny:
  ├─ Average Processing Ratio: 0.29x realtime
  ├─ First-Word Latency: 1.9 seconds
  ├─ Backpressure Events: 0
  ├─ Compute Unit: Neural Engine (ANE)
  └─ User Quality Rating: Good

  ✅ STREAMING VIABLE

Continue to next model (openai_whisper-base)? [Y/n]:
```

---

## Final Report Example

```
═══════════════════════════════════════════════════════════════
           Whisper Streaming Benchmark Results
═══════════════════════════════════════════════════════════════

Machine: MacBook Pro M3 Max (36GB RAM)
macOS:   14.2 (Sonoma)
Date:    2026-01-06 14:32:15

┌─────────────────────┬──────────┬───────────┬────────┬────────────────┐
│ Model               │ Ratio    │ Latency   │ Compute│ Status         │
├─────────────────────┼──────────┼───────────┼────────┼────────────────┤
│ whisper-tiny        │ 0.29x    │ 1.9s      │ ANE    │ ✅ Viable      │
│ whisper-base        │ 0.45x    │ 2.1s      │ ANE    │ ✅ Viable      │
│ whisper-small       │ 0.72x    │ 2.4s      │ ANE    │ ✅ Viable      │
│ whisper-medium      │ 1.4x     │ 3.2s      │ GPU    │ ⚠️  Marginal   │
│ whisper-large-v3    │ 2.8x     │ 5.8s      │ GPU    │ ❌ Not Viable  │
└─────────────────────┴──────────┴───────────┴────────┴────────────────┘

Legend:
  Ratio    = processing_time / audio_duration (< 1.0 required for streaming)
  Latency  = time from recording start to first word displayed
  Compute  = ANE (Neural Engine) or GPU
  Viable   = ratio < 1.0, latency < 3.0s, zero backpressure
  Marginal = ratio 1.0-1.5x, may work for slow/deliberate speech
  Not Viable = ratio > 1.5x, causes audio backlog

Recommendation:
  For real-time streaming on this hardware, use whisper-small or smaller.
  whisper-medium may work for slow, deliberate dictation.
  whisper-large-v3 should only be used in batch (non-streaming) mode.

Results saved to: ~/Documents/whisper-streaming-benchmark-2026-01-06.json
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `Package.swift` | Swift Package manifest with WhisperKit + ArgumentParser |
| `README.md` | Setup instructions, model download guide, permission notes |
| `.gitignore` | Ignore .build/, .swiftpm/, etc. |
| `Sources/StreamingBenchmark/main.swift` | CLI entry point with ArgumentParser command |
| `Sources/StreamingBenchmark/BenchmarkRunner.swift` | Test orchestration, model progression, warmup |
| `Sources/StreamingBenchmark/LiveTranscriber.swift` | WhisperKit streaming integration with LocalAgreement-2 |
| `Sources/StreamingBenchmark/AudioCapture.swift` | AVFoundation microphone input (16kHz, 1.5s chunks) |
| `Sources/StreamingBenchmark/TerminalDisplay.swift` | ANSI terminal output with unconfirmed token marking |
| `Sources/StreamingBenchmark/Metrics.swift` | Timing collection, processing ratio, backpressure detection |
| `Sources/StreamingBenchmark/ComputeInfo.swift` | ANE/GPU detection and reporting |
| `Sources/StreamingBenchmark/ResultsReporter.swift` | Final summary table and JSON export |

---

## Dependencies

- **WhisperKit** (0.9.0+) - Provides Whisper model inference and streaming API
- **swift-argument-parser** (1.3.0+) - CLI argument parsing
- **AVFoundation** - System framework for audio capture (system library)
- **Metal** - GPU compute detection (system library)

---

## Model Pre-Download

Models must be downloaded before running the benchmark. WhisperKit stores models in:
```
~/Library/Caches/com.argmax.whisperkit/
```

**Download options:**

1. **Using WhisperKit CLI** (if available):
   ```bash
   whisperkit-cli download --model openai_whisper-tiny
   whisperkit-cli download --model openai_whisper-base
   whisperkit-cli download --model openai_whisper-small
   whisperkit-cli download --model openai_whisper-medium
   whisperkit-cli download --model openai_whisper-large-v3
   ```

2. **Using any WhisperKit-based app**:
   - Open app settings
   - Select each model to trigger download

3. **Programmatic download** (first-run fallback):
   - If model not found, display error with download instructions
   - Do NOT auto-download during benchmark (skews timing)
   - Skip missing models and continue with available ones

---

## Testing the Benchmark Tool

```bash
# Build
swift build -c release

# Run
.build/release/streaming-benchmark

# Follow interactive prompts
# Review results in terminal and ~/Documents/whisper-streaming-benchmark-*.json
```

---

## Success Criteria for This Plan

- [ ] CLI tool builds and runs from terminal
- [ ] Audio capture works with system microphone
- [ ] Warmup phase runs before each model test
- [ ] Streaming transcription displays words in real-time with unconfirmed tokens marked
- [ ] Processing ratio, first-word latency, and backpressure are calculated correctly
- [ ] Compute unit (ANE/GPU) is detected and reported
- [ ] All 5 models can be tested in sequence (tiny, base, small, medium, large-v3)
- [ ] Minimum 20-second recording enforced
- [ ] Final report shows clear recommendation with all metrics
- [ ] Results exported to JSON with full timing data

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Microphone permissions in CLI | See detailed section below |
| Models not pre-downloaded | Clear error message with download instructions; fail fast |
| Terminal display flickers | Use ANSI escape codes for smooth cursor control; redraw only changed lines |
| WhisperKit streaming API changed | Verify API before implementation; document version tested |
| Swift Package resolution slow | Pin WhisperKit version, use release builds |
| First inference slower than steady-state | Warmup phase discards first run |
| User speaks too briefly | Enforce minimum 20-second recording |

### Microphone Permissions for CLI Tools

macOS TCC (Transparency, Consent, and Control) requires explicit user authorization for microphone access. CLI tools have specific challenges:

**Option A: Signed CLI executable (Recommended)**
- Code-sign the executable with a Developer ID
- On first run, macOS will show a permission dialog
- Permission is remembered per-executable path
- Works without an app bundle

```bash
# Sign the built executable
codesign --sign "Developer ID Application: Your Name" \
    --options runtime \
    .build/release/streaming-benchmark
```

**Option B: Run via Terminal.app**
- If Terminal.app already has microphone permission, CLI tools inherit it
- User must grant Terminal.app microphone access in System Settings > Privacy & Security > Microphone
- Document this in README as fallback

**Option C: Create minimal app bundle wrapper**
- Create a `.app` bundle with Info.plist containing NSMicrophoneUsageDescription
- Embed the CLI tool inside
- More complex but guarantees proper permission flow

**Recommendation:** Start with Option A (signed executable). Document Option B as fallback. Only pursue Option C if permission issues persist.

### Error Handling

The tool must handle these error conditions gracefully:

| Error | Detection | Recovery |
|-------|-----------|----------|
| Microphone permission denied | AVCaptureDevice.authorizationStatus | Display instructions to grant in System Settings; exit with code 1 |
| Model not found | WhisperKit throws on load | List available models; show download instructions; skip to next model |
| Model fails to load (corrupted) | WhisperKit throws on load | Suggest re-downloading model; skip to next model |
| Audio capture fails mid-test | AVAudioEngine error callback | Stop test gracefully; report partial results; offer retry |
| WhisperKit inference crashes | Catch Swift errors | Log error; skip to next model; note in final report |
| User Ctrl+C during test | Signal handler | Save partial results; clean exit |
| Insufficient disk space for results | Write failure | Warn user; print results to stdout instead |

**Error Exit Codes:**
- `0` - Success (all requested models tested)
- `1` - Permission denied (microphone)
- `2` - No models found
- `3` - Partial completion (some models failed)
- `4` - Fatal error (couldn't start)

---

## Next Steps

1. Get approval on this plan
2. Verify WhisperKit streaming API (check `segmentDiscoveryCallback` exists in 0.9.x)
3. Create new GitHub repo `whisper-streaming-benchmark`
4. Initialize Swift Package with WhisperKit + ArgumentParser dependencies
5. Implement audio capture and terminal display (Phase 1)
6. Integrate WhisperKit streaming with LocalAgreement-2 (Phase 2)
7. Add warmup, metrics collection, and compute unit detection (Phase 3)
8. Test with all 5 models and document results
9. Document microphone permission setup in README

---

*Awaiting approval before implementation.*
