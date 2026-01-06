# CLAUDE.md

> **Project**: WisprFlow - macOS on-device voice-to-text transcription
> **Architecture**: Swift/SwiftUI menu bar app + WhisperKit for local inference
> **Platform**: macOS (Apple Silicon)

---

## Project Overview

WisprFlow is a macOS menu bar application for on-device voice-to-text transcription. Users double-tap the right Option key to start recording, speak, and the transcribed text is automatically inserted at the cursor position via clipboard paste. The app uses WhisperKit for local Whisper model inference on Apple Silicon, requiring no internet connection or API keys.

**Key features:**
- Hotkey-triggered recording (right Option double-tap)
- On-device transcription using WhisperKit (base or large models)
- Automatic text insertion at cursor via clipboard paste
- Transcription history with click-to-copy
- Menu bar status indicator

---

## Critical Rules

1. **Push after every change** - Do not accumulate changes locally. Each meaningful change must be committed and pushed immediately.
2. **Read before modifying** - Never propose changes to code you haven't read. Understand existing patterns first.
3. **Stop at architecture decisions** - Major architectural changes require explicit human approval before implementation.
4. **No silent failures** - Document blockers and concerns; don't proceed hoping issues resolve themselves.

---

## Active Implementation: Streaming Transcription

> **MANDATORY:** When working on the `streaming-implementation` branch, you MUST follow the TODO document strictly.

### Required Workflow

1. **Open the TODO first**: Read `docs/streaming-implementation/TODO.md` before starting any work
2. **Mark tasks in progress**: When you begin a task, change `[ ]` to `[IN PROGRESS]`
3. **Mark tasks complete**: When finished, change `[IN PROGRESS]` to `[x]`
4. **Follow phase order**: Do NOT skip ahead. Phase 0 blocks all other phases.
5. **Commit TODO updates**: Include TODO.md changes in your commits

### TODO Document Location

```
docs/streaming-implementation/TODO.md
```

### Phase Dependencies

```
Phase 0 (BLOCKING) → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5
```

**Phase 0 must be 100% complete before ANY code from Phases 1-5 is written.**

### Supporting Documentation

| Document | Purpose |
|----------|---------|
| `00-overview.md` | High-level overview, blocking requirements |
| `01-architecture.md` | State machine, configuration, logging |
| `02-implementation-guide.md` | Complete code samples |
| `03-testing-plan.md` | Test cases, performance targets |
| `04-risks-and-changelog.md` | Risk mitigation, version history |

---

## Development Lifecycle (PRIME Loop)

Follow this cycle for features and tasks:

```
PLAN → RESEARCH → IMPLEMENT → MEASURE → EVOLVE
```

- **Plan**: Define objectives, break into tasks, identify risks
- **Research**: Read existing code, understand patterns, gather context
- **Implement**: Build incrementally, test as you go
- **Measure**: Validate against requirements, run tests
- **Evolve**: Refactor based on findings, update documentation

---

## Project Structure

```
WisprFlow/
├── App/
│   ├── WisprFlowApp.swift       # App entry point
│   └── AppDelegate.swift        # Menu bar, hotkey setup
├── Features/
│   ├── Transcription/           # Audio recording, transcription logic
│   ├── ModelDownload/           # WhisperKit model management
│   └── Settings/                # User preferences
├── UI/
│   └── Components/              # Reusable SwiftUI views
├── Services/                    # Shared services (clipboard, permissions)
└── Resources/                   # Assets, localization
docs/
├── plans/                       # Implementation plans
└── *.md                         # Technical documentation
```

---

## Code Standards

### Swift/SwiftUI Conventions

```swift
// Use Swift's strong typing - avoid Any/AnyObject
// Prefer struct over class for data models
// Use @MainActor for UI-related code
// Handle optionals explicitly (guard let, if let)
// Use async/await over completion handlers
// Document public APIs with /// comments
```

### Patterns in This Codebase

- **State Management**: `@Observable` classes with `@MainActor`
- **Error Handling**: Explicit error types, user-facing error messages
- **Concurrency**: Swift structured concurrency (async/await, Task)
- **Dependency Injection**: Protocol-based services for testability

### Testing Requirements

- Unit tests for core logic (transcription, model management)
- Test files mirror source structure in `WisprFlowTests/`
- Tests must pass before push

---

## macOS-Specific Notes

### Required Permissions

The app requires these entitlements/permissions:
- **Microphone access** - For audio recording
- **Accessibility** - For keyboard event monitoring (hotkey detection)
- **Automation** - For pasting text into other applications

### WhisperKit Integration

- Models are downloaded on first launch or on-demand
- Supported models: `base`, `large-v3` (configurable)
- Model files stored in app's Application Support directory
- All inference runs locally on Apple Neural Engine / GPU

---

## Git Workflow

### Commit Conventions

```
<type>: <description>

Types: feat, fix, docs, refactor, test, chore

Examples:
feat: add streaming transcription support
fix: resolve audio session interruption handling
docs: update model download documentation
```

### Push Cadence

**Push to remote after:**
- Completing any task
- Before ending any session
- After resolving any blocker

**Push checklist:**
1. Code compiles without warnings
2. Tests pass
3. Meaningful commit message

---

## Decision Escalation

| Situation | Action |
|-----------|--------|
| Which approach for a bug fix | Proceed with best judgment |
| API/interface design choice | Recommend and explain rationale |
| Architecture change | **STOP** - Ask for approval |
| Security concern | **STOP** - Report immediately |
| Scope addition | **STOP** - Confirm with human |
| Performance tradeoff | Recommend with tradeoff analysis |

---

## Problem-Solving Protocol

When stuck, follow this sequence:

### 1. Self-Diagnose
- Re-read error messages carefully
- Check recent changes that might have caused it
- Search codebase for similar patterns

### 2. Research
- Check Apple documentation
- Look for existing solutions in codebase
- Review WhisperKit documentation if model-related

### 3. Experiment
- Try isolated fixes
- Add diagnostic logging
- Test assumptions in isolation

### 4. Escalate
If still stuck, document:
- What you're trying to do
- What's happening vs. expected
- What you've tried
- Your hypothesis on root cause

---

## Session Checklists

### Starting Work

- [ ] Pull latest from remote
- [ ] Review recent commits for context
- [ ] Check for any pending issues or TODOs
- [ ] Verify project builds and tests pass

### Ending Work

- [ ] All changes committed with clear messages
- [ ] Pushed to remote
- [ ] No uncommitted files
- [ ] Brief note on what's next (if applicable)

---

## Quick Reference

### Build Commands

```bash
# Build from command line
xcodebuild -scheme WisprFlow -configuration Debug build

# Run tests
xcodebuild -scheme WisprFlow -configuration Debug test

# Open in Xcode
open WisprFlow.xcodeproj
```

### Key Files

| What | Where |
|------|-------|
| App entry | `WisprFlow/App/WisprFlowApp.swift` |
| Hotkey handling | `WisprFlow/App/AppDelegate.swift` |
| Transcription | `WisprFlow/Features/Transcription/` |
| Model download | `WisprFlow/Features/ModelDownload/` |
| Plans & docs | `docs/` |

---

*Adapted from multi-agent development system patterns*
*Last updated: 2025-01-01*
