# Whisper Streaming Benchmark

A terminal-based tool that benchmarks which Whisper models can support live streaming transcription on your hardware.

## Overview

This tool tests Whisper models from smallest (tiny) to largest (large-v3), measuring:

- **Processing Ratio** - How fast the model processes audio relative to realtime (< 1.0x required for streaming)
- **First-Word Latency** - Time from speaking to first transcription appearing
- **Backpressure Events** - When processing can't keep up with incoming audio
- **Compute Unit** - Whether the model runs on Neural Engine (ANE) or GPU

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3)
- Xcode Command Line Tools
- Microphone access

## Installation

```bash
# Clone the repository
git clone https://github.com/[user]/whisper-streaming-benchmark.git
cd whisper-streaming-benchmark

# Build
swift build -c release
```

## Model Download

Models must be downloaded before running the benchmark. WhisperKit stores models in:
```
~/Library/Caches/com.argmax.whisperkit/
```

### Download Options

**Option 1: Using WhisperKit CLI**
```bash
whisperkit-cli download --model openai_whisper-tiny
whisperkit-cli download --model openai_whisper-base
whisperkit-cli download --model openai_whisper-small
whisperkit-cli download --model openai_whisper-medium
whisperkit-cli download --model openai_whisper-large-v3
```

**Option 2: Using any WhisperKit-based app**
- Open the app's settings
- Select each model to trigger download

**Option 3: Programmatic (first-run)**
- The benchmark will show available models
- Download missing models using one of the above methods

## Usage

```bash
# Run full benchmark (all models)
.build/release/streaming-benchmark

# Test a specific model only
.build/release/streaming-benchmark --model openai_whisper-small

# Show detailed per-chunk timing
.build/release/streaming-benchmark --verbose

# Skip warmup (debugging)
.build/release/streaming-benchmark --skip-warmup

# Custom output path
.build/release/streaming-benchmark --output ~/my-results.json
```

### CLI Options

| Flag | Description |
|------|-------------|
| `--model <name>` | Test only a specific model |
| `--skip-warmup` | Skip the warmup phase |
| `--output <path>` | Custom JSON output path |
| `--verbose` | Show timing for each chunk |
| `--help` | Show help information |

## Microphone Permissions

CLI tools require explicit microphone authorization.

### Option A: Grant Terminal.app Access (Recommended)
1. Open **System Settings** > **Privacy & Security** > **Microphone**
2. Enable access for **Terminal.app** (or your terminal emulator)
3. Re-run the benchmark

### Option B: Sign the Executable
```bash
codesign --sign "Developer ID Application: Your Name" \
    --options runtime \
    .build/release/streaming-benchmark
```

## Interpreting Results

### Viability Status

| Status | Processing Ratio | Meaning |
|--------|-----------------|---------|
| **Viable** | < 1.0x | Model processes faster than realtime, suitable for streaming |
| **Marginal** | 1.0x - 1.5x | May work for slow, deliberate speech |
| **Not Viable** | > 1.5x | Causes audio backlog, not suitable for streaming |

### Success Criteria

A model is streaming-viable if:
- Processing ratio < 1.0x realtime
- First-word latency < 3.0 seconds
- Zero backpressure events
- User confirms transcription is readable

### Example Results

```
+---------------------+----------+-----------+--------+----------------+
| Model               | Ratio    | Latency   |Compute | Status         |
+---------------------+----------+-----------+--------+----------------+
| whisper-tiny        | 0.29x    | 1.9s      | ANE    | [+] Viable     |
| whisper-base        | 0.45x    | 2.1s      | ANE    | [+] Viable     |
| whisper-small       | 0.72x    | 2.4s      | ANE    | [+] Viable     |
| whisper-medium      | 1.4x     | 3.2s      | GPU    | [~] Marginal   |
| whisper-large-v3    | 2.8x     | 5.8s      | GPU    | [x] Not Viable |
+---------------------+----------+-----------+--------+----------------+
```

## Output

Results are saved to JSON for further analysis:
```
~/Documents/whisper-streaming-benchmark-YYYY-MM-DD.json
```

The JSON includes:
- System information (machine model, RAM, macOS version)
- Per-model metrics
- Individual chunk timings

## How It Works

1. **Load Model** - Initialize WhisperKit with the specified model
2. **Warmup** - Run a short inference to prime caches (discarded)
3. **Record** - Capture ~30 seconds of speech from microphone
4. **Stream** - Process audio in 1.5s chunks with 0.25s overlap
5. **Display** - Show transcription in real-time with unconfirmed tokens marked
6. **Measure** - Calculate processing ratio, latency, and backpressure
7. **Report** - Generate summary and save to JSON

### LocalAgreement-2 Policy

Tokens are considered "confirmed" when they appear consistently across 3 consecutive chunk transcriptions. The last 2 tokens are always displayed as "unconfirmed" (in brackets) since they may change with more audio context.

## Troubleshooting

### "Microphone permission denied"
Grant Terminal.app microphone access in System Settings > Privacy & Security > Microphone.

### "Model not found"
Download the model first using WhisperKit CLI or a WhisperKit-based app.

### Build fails
Ensure you have Xcode Command Line Tools installed:
```bash
xcode-select --install
```

## License

MIT License
