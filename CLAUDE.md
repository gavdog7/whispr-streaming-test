# CLAUDE.md

> **Project**: whisper-streaming-benchmark - CLI tool to benchmark Whisper streaming performance
> **Architecture**: Swift Package CLI tool + WhisperKit + ArgumentParser
> **Platform**: macOS 14+ (Apple Silicon)

---

## Project Overview

A terminal-based tool that benchmarks which Whisper models can support live streaming transcription on the current hardware. The tool tests models from smallest (tiny) to largest (large-v3), measuring processing ratio, latency, and backpressure to determine streaming viability.

**Key features:**
- Tests all 5 Whisper models in sequence (tiny, base, small, medium, large-v3)
- Real-time transcription display with unconfirmed token marking
- Warmup phase before each test (discards first inference)
- Metrics: processing ratio, first-word latency, backpressure events, compute unit (ANE/GPU)
- Final report with streaming viability recommendation
- JSON export of results

**Reference:** See `docs/streaming-benchmark-test.md` for complete implementation plan and specifications.

---

## Critical Rules

1. **Push after every change** - Do not accumulate changes locally. Each meaningful change must be committed and pushed immediately.
2. **Read before modifying** - Never propose changes to code you haven't read. Understand existing patterns first.
3. **Stop at architecture decisions** - Major architectural changes require explicit human approval before implementation.
4. **No silent failures** - Document blockers and concerns; don't proceed hoping issues resolve themselves.

---

## Active Implementation

> **MANDATORY:** Follow the implementation plan and track progress via TODO.

### Required Workflow

1. **Check the plan first**: Read `docs/streaming-benchmark-test.md` before starting work
2. **Use TODO tracking**: Maintain a TODO list in this file (below) for current tasks
3. **Follow phase order**: Complete phases in sequence (Phase 1 → 2 → 3)
4. **Commit progress**: Include TODO updates in your commits

### Implementation Phases

```
Phase 1 (Infrastructure) → Phase 2 (Streaming) → Phase 3 (Benchmark Logic)
```

### Current TODO

<!-- Update this section as you work. Mark items [x] when complete. -->

- [ ] Phase 1: Basic Infrastructure
  - [ ] Create Package.swift with WhisperKit + ArgumentParser dependencies
  - [ ] Verify package builds
  - [ ] Implement AudioCapture.swift (AVFoundation, 16kHz, start/stop)
  - [ ] Implement TerminalDisplay.swift (ANSI escape codes, live updates)
  - [ ] Implement main.swift with ArgumentParser command structure

- [ ] Phase 2: Streaming Integration
  - [ ] Implement LiveTranscriber.swift (WhisperKit streaming wrapper)
  - [ ] Configure segmentDiscoveryCallback for streaming
  - [ ] Implement LocalAgreement-2 confirmation logic
  - [ ] Display confirmed vs unconfirmed tokens

- [ ] Phase 3: Benchmark Logic
  - [ ] Implement BenchmarkRunner.swift (model progression, warmup)
  - [ ] Implement Metrics.swift (timing, processing ratio, backpressure)
  - [ ] Implement ComputeInfo.swift (ANE/GPU detection)
  - [ ] Implement ResultsReporter.swift (summary table, JSON export)
  - [ ] Add user quality assessment prompt
  - [ ] Test with all 5 models

---

## Development Lifecycle (PRIME Loop)

```
PLAN → RESEARCH → IMPLEMENT → MEASURE → EVOLVE
```

- **Plan**: Review implementation plan, break into tasks
- **Research**: Read existing code, check WhisperKit API
- **Implement**: Build incrementally, test as you go
- **Measure**: Validate against success criteria
- **Evolve**: Refactor based on findings

---

## Project Structure

```
whisper-streaming-benchmark/
├── Package.swift                    # Swift Package manifest
├── CLAUDE.md                        # This file
├── README.md                        # Setup and usage instructions
├── .gitignore
├── docs/
│   └── streaming-benchmark-test.md  # Implementation plan
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
```

---

## Code Standards

### Swift Conventions

```swift
// Use Swift's strong typing - avoid Any/AnyObject
// Prefer struct over class for data models
// Use async/await over completion handlers
// Handle optionals explicitly (guard let, if let)
// Document public APIs with /// comments
```

### Patterns for This Project

- **Concurrency**: Swift structured concurrency (async/await, Task)
- **Error Handling**: Explicit error types with clear exit codes
- **CLI Output**: ANSI escape codes for terminal control

---

## Build & Run

```bash
# Build
swift build -c release

# Run (interactive benchmark)
.build/release/streaming-benchmark

# Run specific model only
.build/release/streaming-benchmark --model openai_whisper-small

# Verbose output (show per-chunk timing)
.build/release/streaming-benchmark --verbose
```

### CLI Flags

| Flag | Description |
|------|-------------|
| `--model <name>` | Test only a specific model |
| `--skip-warmup` | Skip warmup phase (debugging) |
| `--output <path>` | Custom JSON output path |
| `--verbose` | Show detailed timing for each chunk |

---

## Microphone Permissions

CLI tools require explicit microphone authorization. Options:

1. **Terminal.app permission** (easiest): Grant Terminal.app microphone access in System Settings > Privacy & Security > Microphone

2. **Signed executable**: Code-sign the built executable:
   ```bash
   codesign --sign "Developer ID Application: Your Name" \
       --options runtime \
       .build/release/streaming-benchmark
   ```

If permission is denied, the tool exits with code 1 and displays instructions.

---

## Git Workflow

### Commit Conventions

```
<type>: <description>

Types: feat, fix, docs, refactor, test, chore

Examples:
feat: implement audio capture with 16kHz sampling
fix: resolve chunk timing calculation
docs: add microphone permission instructions
```

### Push Cadence

**Push to remote after:**
- Completing any task
- Before ending any session
- After resolving any blocker

---

## Decision Escalation

| Situation | Action |
|-----------|--------|
| Which approach for a bug fix | Proceed with best judgment |
| API/interface design choice | Recommend and explain rationale |
| Architecture change | **STOP** - Ask for approval |
| WhisperKit API different than expected | **STOP** - Report and update plan |
| Scope addition | **STOP** - Confirm with human |

---

## Problem-Solving Protocol

When stuck:

1. **Self-Diagnose** - Re-read errors, check recent changes
2. **Research** - Check WhisperKit docs, Apple docs
3. **Experiment** - Try isolated fixes, add logging
4. **Escalate** - Document what's happening vs expected, what you tried

---

## Session Checklists

### Starting Work

- [ ] Pull latest from remote
- [ ] Review current TODO status
- [ ] Verify project builds (`swift build`)

### Ending Work

- [ ] All changes committed with clear messages
- [ ] TODO updated with progress
- [ ] Pushed to remote

---

## Quick Reference

### Key Files

| What | Where |
|------|-------|
| Implementation plan | `docs/streaming-benchmark-test.md` |
| CLI entry point | `Sources/StreamingBenchmark/main.swift` |
| Test orchestration | `Sources/StreamingBenchmark/BenchmarkRunner.swift` |
| WhisperKit streaming | `Sources/StreamingBenchmark/LiveTranscriber.swift` |
| Audio capture | `Sources/StreamingBenchmark/AudioCapture.swift` |

### Success Criteria (from plan)

- Processing ratio < 1.0x realtime
- First-word latency < 3.0 seconds
- Zero backpressure events
- User confirms transcription is readable

---

*Reference: docs/streaming-benchmark-test.md for complete specifications*
