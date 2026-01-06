# Implementation Plan: UX Improvements

**Source:** `docs/feedback/2026-01-06-ux-improvements.md`
**Date:** 2026-01-06
**Status:** Ready for implementation

---

## Overview

This plan restructures the benchmark flow to reduce cognitive load. The main changes:
1. Pre-download all models before testing
2. Add passage pool with random selection
3. Stacked layout (reference zone above transcript)
4. Persistent transcript accumulation
5. Review phase before quality rating

---

## Phase 1: Model Pre-Download

**Goal:** Download all models upfront before any testing begins.

### Files to Modify
- `Sources/StreamingBenchmark/BenchmarkRunner.swift`
- `Sources/StreamingBenchmark/TerminalDisplay.swift`

### Changes

#### 1.1 Add download progress display (TerminalDisplay.swift)

```swift
func showDownloadPhase(models: [String]) {
    print("\n\(bold)Preparing Models\(reset)")
    print("Checking \(models.count) models before benchmark begins...\n")
}

func showModelStatus(index: Int, total: Int, modelName: String, status: ModelDownloadStatus) {
    switch status {
    case .alreadyDownloaded:
        print("  [\(index)/\(total)] \(green)✓\(reset) \(modelName) (cached)")
    case .downloading:
        print("  [\(index)/\(total)] Downloading \(modelName)...")
    case .downloaded:
        print("  [\(index)/\(total)] \(green)✓\(reset) \(modelName) (downloaded)")
    case .failed(let error):
        print("  [\(index)/\(total)] \(red)✗\(reset) \(modelName) - \(error)")
    }
}

func showDownloadComplete(successful: Int, failed: Int) {
    if failed == 0 {
        print("\n\(green)All \(successful) models ready.\(reset)\n")
    } else {
        print("\n\(yellow)\(successful) models ready, \(failed) failed.\(reset)")
        print("Benchmark will skip failed models.\n")
    }
}

enum ModelDownloadStatus {
    case alreadyDownloaded
    case downloading
    case downloaded
    case failed(String)
}
```

#### 1.2 Add pre-download phase (BenchmarkRunner.swift)

```swift
/// Downloads all models that aren't already cached
private func downloadAllModels() async -> [String: Bool] {
    display.showDownloadPhase(models: allModels)

    var results: [String: Bool] = [:]

    for (index, model) in allModels.enumerated() {
        let modelIndex = index + 1

        // Check if already downloaded
        if await transcriber.modelExists(name: model) {
            display.showModelStatus(index: modelIndex, total: allModels.count,
                                   modelName: model, status: .alreadyDownloaded)
            results[model] = true
            continue
        }

        // Need to download - use WhisperKit's download mechanism
        display.showModelStatus(index: modelIndex, total: allModels.count,
                               modelName: model, status: .downloading)

        do {
            // Download model files without fully loading into memory
            // Note: WhisperKit downloads on first load; we load briefly then unload
            _ = try await transcriber.loadModel(name: model)
            transcriber.unload()  // Free memory, files remain cached

            display.showModelStatus(index: modelIndex, total: allModels.count,
                                   modelName: model, status: .downloaded)
            results[model] = true
        } catch {
            display.showModelStatus(index: modelIndex, total: allModels.count,
                                   modelName: model, status: .failed(error.localizedDescription))
            results[model] = false
        }
    }

    let successful = results.values.filter { $0 }.count
    let failed = results.values.filter { !$0 }.count
    display.showDownloadComplete(successful: successful, failed: failed)

    return results
}
```

Call `downloadAllModels()` at the start of `run()` and skip models that failed to download.

### Technical Notes

- WhisperKit downloads model files to `~/Library/Caches/com.argmax.whisperkit/` on first load
- The `loadModel()` → `unload()` pattern downloads files and releases memory
- Files remain cached for subsequent loads during actual benchmark
- Network failures are caught and reported; benchmark continues with available models

### Success Criteria
- All models download before first test prompt
- Progress shows "Checking 5 models before benchmark begins..."
- Failed downloads are reported, not fatal
- No download interruptions during testing

---

## Phase 2: Passage Pool

**Goal:** Provide varied, conversational passages for natural reading.

### Files to Create
- `Sources/StreamingBenchmark/Passages.swift`

### Files to Modify
- `Sources/StreamingBenchmark/BenchmarkRunner.swift`
- `Sources/StreamingBenchmark/TerminalDisplay.swift`

### Changes

#### 2.1 Create Passages.swift

```swift
/// Pool of conversational passages for benchmark testing
struct Passages {
    /// All available passages (~30-45 seconds each when read naturally)
    static let all: [String] = [
        """
        I was walking to the coffee shop this morning when I ran into an old friend. \
        We hadn't seen each other in years, so we decided to catch up over breakfast. \
        She told me about her new job and how much she loves working from home. \
        The flexibility has really changed her life for the better.
        """,

        """
        Last weekend I finally cleaned out my garage. It took the whole day, but I found \
        so many things I forgot I had. Old photos, my first guitar, even some letters \
        from college. It's funny how objects can bring back so many memories. \
        I ended up spending more time reminiscing than actually organizing.
        """,

        """
        My neighbor has the most beautiful garden. Every spring she plants tomatoes, \
        peppers, and herbs. She always shares her harvest with everyone on the street. \
        Last summer she gave me so many zucchinis I didn't know what to do with them. \
        I must have made a dozen loaves of zucchini bread.
        """,

        """
        I've been trying to learn how to cook more lately. Started with simple things \
        like pasta and scrambled eggs. Now I'm getting into soups and stir fries. \
        The key is not being afraid to make mistakes. Some of my best dishes came \
        from happy accidents in the kitchen.
        """,

        """
        We took a road trip to the coast last month. The drive was about four hours, \
        but we stopped at this little diner halfway there. Best pancakes I've ever had. \
        The beach was perfect, not too crowded. We stayed until sunset watching the \
        waves roll in.
        """,

        """
        My kids have been asking for a dog for years. We finally adopted one from the \
        shelter last week. She's a mix of something and something else, very sweet. \
        The house has been chaos ever since, but the good kind. Everyone fights over \
        who gets to take her for walks.
        """,

        """
        I started running a few months ago. Just around the block at first, then longer \
        routes through the park. It's become my favorite part of the morning. The quiet \
        streets, the sunrise, just me and my thoughts. I never thought I'd be a morning \
        person, but here we are.
        """,

        """
        There's this little bookstore downtown that I love. It's been there for decades, \
        run by the same family. They have a cat that sleeps in the window. I always \
        find something unexpected there, books I never would have picked up otherwise. \
        Last visit I discovered this amazing mystery series.
        """,

        """
        We're planning a family reunion for next summer. It's been five years since we \
        all got together. My cousins are flying in from across the country. We rented \
        a big cabin by the lake. There's going to be so much food and catching up. \
        I can't wait to see everyone.
        """,

        """
        I've been watching a lot of documentaries about space lately. It's incredible \
        how much we've learned in just the last few years. The images from those new \
        telescopes are amazing. Makes you feel small but also connected to something \
        much bigger. We're all made of star stuff, as they say.
        """
    ]

    /// Get a random passage, excluding recently used indices
    /// - Parameter excluding: Set of passage indices to exclude from selection
    /// - Returns: Tuple of (index, passage text)
    static func random(excluding: Set<Int> = []) -> (index: Int, text: String) {
        var available = Array(all.indices).filter { !excluding.contains($0) }

        // Reset if we've used all passages
        if available.isEmpty {
            available = Array(all.indices)
        }

        // Safe random selection (guard against empty array, though shouldn't happen)
        guard let index = available.randomElement() else {
            return (0, all[0])
        }

        return (index, all[index])
    }
}
```

#### 2.2 Passage requirements
- 10 passages (enough for 2 full benchmark runs without repetition)
- Conversational tone (like talking to a friend)
- Natural speech patterns, no jargon or tongue-twisters
- ~30-45 seconds at normal reading pace
- Varied topics: daily life, travel, food, memories, hobbies

#### 2.3 Update BenchmarkRunner to track used passages

Add property:
```swift
private var usedPassageIndices: Set<Int> = []
```

Select passage for each model test:
```swift
let (passageIndex, passage) = Passages.random(excluding: usedPassageIndices)
usedPassageIndices.insert(passageIndex)
```

#### 2.4 Update TerminalDisplay.showInstructions()

Change signature to accept passage text:
```swift
func showTestInstructions(passage: String)
```

### Success Criteria
- Each model test shows a different passage
- Passages are natural to read aloud
- No pangrams or formal technical text
- Safe fallback if random selection somehow fails

---

## Phase 3: Stacked Layout

**Goal:** Display reference text above transcript for easy comparison without complex column management.

### Design Rationale

Side-by-side layout requires:
- Column width calculations
- Terminal width detection
- Complex cursor management for two updating regions
- Minimum 95-character terminal width

Stacked layout is simpler:
- Reference text at top (static after initial render)
- Transcript updates below (single region to manage)
- Works on any terminal width (just word-wrap)
- User glances up at reference, watches transcript below

### Terminal Layout Specification

```
┌─────────────────────────────────────────────────────────────────┐
│  REFERENCE (read this aloud):                                   │
│                                                                 │
│  I was walking to the coffee shop this morning when I ran      │
│  into an old friend. We hadn't seen each other in years, so    │
│  we decided to catch up over breakfast. She told me about      │
│  her new job and how much she loves working from home.         │
└─────────────────────────────────────────────────────────────────┘

Recording... ● [00:23]

YOUR TRANSCRIPT:
─────────────────────────────────────────────────────────────────
I was walking to the coffee shop this morning when I ran into
an old friend we hadn't seen each other in years [so we decided]

(Words in [brackets] are unconfirmed - may change)
```

### Files to Modify
- `Sources/StreamingBenchmark/TerminalDisplay.swift`
- `Sources/StreamingBenchmark/BenchmarkRunner.swift`

### Changes

#### 3.1 Add reference display (TerminalDisplay.swift)

```swift
private var referenceLineCount: Int = 0

/// Display the reference passage in a bordered box
func showReferencePassage(_ passage: String) {
    let boxWidth = min(terminalWidth - 2, 70)  // Cap at 70 for readability
    let innerWidth = boxWidth - 4  // Account for border and padding

    let wrapped = wordWrap(passage, width: innerWidth)
    let lines = wrapped.components(separatedBy: "\n")

    // Top border
    print("┌" + String(repeating: "─", count: boxWidth - 2) + "┐")

    // Header
    print("│  \(bold)REFERENCE (read this aloud):\(reset)" +
          String(repeating: " ", count: boxWidth - 32) + "│")
    print("│" + String(repeating: " ", count: boxWidth - 2) + "│")

    // Passage lines
    for line in lines {
        let padding = boxWidth - 4 - line.count
        print("│  " + line + String(repeating: " ", count: max(0, padding)) + "  │")
    }

    // Bottom border
    print("└" + String(repeating: "─", count: boxWidth - 2) + "┘")
    print("")  // Blank line before recording status

    referenceLineCount = lines.count + 4  // For potential clear later
}

/// Get terminal width, with fallback
private var terminalWidth: Int {
    // Try to get actual terminal width
    var winsize = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize) == 0 && winsize.ws_col > 0 {
        return Int(winsize.ws_col)
    }
    return 80  // Conservative default
}
```

#### 3.2 Update transcript display

The existing `updateTranscription()` already handles line-by-line updates. Keep this logic but ensure it doesn't interfere with the reference box above.

```swift
func showTranscriptHeader() {
    print("\(bold)YOUR TRANSCRIPT:\(reset)")
    print(String(repeating: "─", count: min(terminalWidth - 1, 70)))
}
```

#### 3.3 Update test flow (BenchmarkRunner.swift)

```swift
// Show reference passage (stays visible)
display.showReferencePassage(passage)

// Show recording prompt
display.showInfo("Press ENTER to start recording...")
display.waitForEnter()

// Show transcript header
display.showTranscriptHeader()

// Start recording and transcription...
```

### Terminal Compatibility Notes

- Box-drawing characters (─, │, ┌, ┐, └, ┘) render correctly in:
  - Terminal.app (macOS)
  - iTerm2
  - VS Code integrated terminal
  - Most modern terminal emulators
- If issues arise, can fall back to ASCII: `-`, `|`, `+`

### Success Criteria
- Reference text visible in bordered box at top
- User can glance up while monitoring transcript below
- Layout works on 80-column terminals
- No complex cursor management needed

---

## Phase 4: Persistent Transcript Accumulation

**Goal:** Build complete transcript for end-of-test review.

### Files to Modify
- `Sources/StreamingBenchmark/LiveTranscriber.swift`
- `Sources/StreamingBenchmark/BenchmarkRunner.swift`

### Changes

#### 4.1 Add accumulated transcript getter (LiveTranscriber.swift)

```swift
/// Get the full accumulated transcript (confirmed + unconfirmed)
/// Note: This class is @MainActor, so access is thread-safe
var fullTranscript: String {
    var text = confirmedText
    if !unconfirmedText.isEmpty {
        if !text.isEmpty && !text.hasSuffix(" ") {
            text += " "
        }
        text += unconfirmedText
    }
    return text.trimmingCharacters(in: .whitespaces)
}
```

#### 4.2 Store transcript with results (BenchmarkRunner.swift)

After recording stops, capture the transcript:

```swift
let finalTranscript = transcriber.fullTranscript
```

Pass to review phase display.

### Thread Safety Note

`LiveTranscriber` is marked `@MainActor`, ensuring all property access happens on the main thread. The `fullTranscript` getter is safe to call after recording stops, as no concurrent mutations will occur.

### Success Criteria
- Full transcript available after each test
- Includes both confirmed and final unconfirmed tokens
- Handles edge case where confirmed text ends without space
- Available for review phase display

---

## Phase 5: Review Phase

**Goal:** Let user review transcript vs reference before rating.

### Files to Modify
- `Sources/StreamingBenchmark/TerminalDisplay.swift`
- `Sources/StreamingBenchmark/BenchmarkRunner.swift`

### Changes

#### 5.1 Add review display (TerminalDisplay.swift)

```swift
func showReviewPhase(passage: String, transcript: String) {
    print("\n")
    print("\(bold)═══════════════════════════════════════════════════════════════\(reset)")
    print("\(bold)                        Review\(reset)")
    print("\(bold)═══════════════════════════════════════════════════════════════\(reset)")
    print("")

    // Show reference
    print("\(bold)REFERENCE:\(reset)")
    print("\(dim)\(wordWrap(passage, width: 65))\(reset)")
    print("")

    // Show transcript
    print("\(bold)TRANSCRIPT:\(reset)")
    print(wordWrap(transcript, width: 65))
    print("")

    print("\(dim)Compare the transcript to the reference above.\(reset)")
    print("\(dim)Press ENTER when ready to rate.\(reset)")
}

func waitForReviewComplete() {
    _ = readLine()
}
```

#### 5.2 Update test flow (BenchmarkRunner.swift)

After recording stops:

```swift
// 1. Get final transcript
let finalTranscript = transcriber.fullTranscript

// 2. Show review phase
display.showReviewPhase(passage: currentPassage, transcript: finalTranscript)

// 3. Wait for user to finish reviewing
display.waitForReviewComplete()

// 4. Then prompt for quality rating
let rating = display.promptQuality()
```

### Success Criteria
- User sees full comparison after recording stops
- Review happens BEFORE quality prompt
- Clear instruction: "Press ENTER when ready to rate"
- Clear visual separation between test and review phases

---

## Phase 6: Quality Rating Update

**Goal:** Improve quality rating prompt after review.

### Files to Modify
- `Sources/StreamingBenchmark/TerminalDisplay.swift`
- `Sources/StreamingBenchmark/Metrics.swift`

### Changes

#### 6.1 Update QualityRating enum (Metrics.swift)

Use integer values for consistency:

```swift
enum QualityRating: Int, Codable, CaseIterable {
    case unusable = 1
    case poor = 2
    case fair = 3
    case good = 4
    case excellent = 5
    case skipped = 0

    var description: String {
        switch self {
        case .unusable: return "Unusable"
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        case .skipped: return "Skipped"
        }
    }
}
```

#### 6.2 Update promptQuality() (TerminalDisplay.swift)

```swift
func promptQuality() -> QualityRating {
    print("\(bold)Rate the transcription quality:\(reset)")
    print("  1 = Unusable  (many errors, hard to understand)")
    print("  2 = Poor      (frequent errors, requires effort)")
    print("  3 = Fair      (some errors, but readable)")
    print("  4 = Good      (minor errors, easy to follow)")
    print("  5 = Excellent (accurate, natural reading)")
    print("")

    while true {
        print("Enter rating (1-5): ", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
            return .skipped
        }

        if input.isEmpty {
            return .skipped
        }

        if let value = Int(input), let rating = QualityRating(rawValue: value) {
            return rating
        }

        print("\(yellow)Please enter a number from 1 to 5.\(reset)")
    }
}
```

#### 6.3 Update JSON export and display

Update `ResultsReporter` to handle integer rating values:

```swift
// In JSON output
"userQualityRating": 4  // Instead of "good"

// In display
"User Rating: 4/5 (Good)"
```

### Backward Compatibility Note

The rating format changes from string ("good"/"poor") to integer (1-5). If there are existing JSON consumers, they will need updating. Document this as a breaking change in release notes.

### Success Criteria
- 1-5 scale with clear descriptions
- Prompt appears after review phase
- Input validation with helpful error message
- Rating stored as integer in results

---

## Implementation Order

```
Phase 1 (Pre-Download)
    → Phase 2 (Passages)
    → Phase 4 (Persistent Transcript)
    → Phase 3 (Stacked Layout)
    → Phase 5 (Review Phase)
    → Phase 6 (Quality Rating)
```

Rationale:
- Phase 1 is independent, do first
- Phase 2 provides passages needed for Phase 3
- Phase 4 is simple and needed for Phase 5
- Phase 3 depends on passages being available
- Phases 5-6 build on previous work

---

## Complexity Assessment

| Phase | Complexity | Key Challenge |
|-------|------------|---------------|
| 1. Pre-Download | Medium | Error handling, progress feedback |
| 2. Passages | Low | Content creation (10 passages) |
| 3. Stacked Layout | Low | Simple box drawing, word wrap |
| 4. Persistent Transcript | Low | Simple property addition |
| 5. Review Phase | Low | Flow restructuring |
| 6. Quality Rating | Low | Enum update, input validation |

Overall complexity reduced from original plan by eliminating side-by-side column management.

---

## Testing Checklist

- [ ] All models download before first test prompt appears
- [ ] Failed downloads are reported but don't crash benchmark
- [ ] Different passage shown for each model test
- [ ] Reference box renders correctly on 80-column terminal
- [ ] Reference box renders correctly on 120-column terminal
- [ ] Transcript accumulates correctly during recording
- [ ] Review phase shows complete comparison
- [ ] "Press ENTER when ready to rate" works correctly
- [ ] Quality rating accepts 1-5, rejects invalid input
- [ ] JSON export includes integer rating (1-5)
- [ ] No regressions in metrics collection

---

## Known Limitations

1. **Terminal resize during test** - Layout may break if terminal is resized mid-test. User should keep terminal size stable during benchmark.

2. **Box-drawing characters** - Requires UTF-8 terminal. ASCII fallback not implemented but could be added if issues arise.

3. **Rating format change** - Breaking change from string to integer. Existing JSON consumers need update.

---

## Files Summary

| File | Changes |
|------|---------|
| `BenchmarkRunner.swift` | Add pre-download, passage selection, review flow |
| `TerminalDisplay.swift` | Add download progress, stacked layout, review display |
| `LiveTranscriber.swift` | Add fullTranscript getter |
| `Passages.swift` | New file with 10 passage pool |
| `Metrics.swift` | Update QualityRating to integer enum |
| `ResultsReporter.swift` | Update for integer rating display |

---

*Implementation ready to begin. Follow phases in order.*
