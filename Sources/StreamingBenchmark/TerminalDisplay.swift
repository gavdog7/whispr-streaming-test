import Foundation
import Darwin

/// Handles terminal output with ANSI escape codes for real-time updates
@MainActor
class TerminalDisplay {
    // ANSI escape codes
    private let reset = "\u{001B}[0m"
    private let bold = "\u{001B}[1m"
    private let dim = "\u{001B}[2m"
    private let red = "\u{001B}[31m"
    private let green = "\u{001B}[32m"
    private let yellow = "\u{001B}[33m"
    private let blue = "\u{001B}[34m"
    private let cyan = "\u{001B}[36m"

    private let clearLine = "\u{001B}[2K"
    private let cursorUp = "\u{001B}[A"
    private let cursorToStart = "\r"
    private let saveCursor = "\u{001B}[s"
    private let restoreCursor = "\u{001B}[u"

    private var lastTranscriptionLines = 0
    private var lastTimingLines = 0
    private var referenceLineCount: Int = 0

    // MARK: - Pre-Download Phase

    /// Download status for a model
    enum ModelDownloadStatus {
        case alreadyDownloaded
        case downloading
        case downloaded
        case failed(String)
    }

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

    // MARK: - Banner and Sections

    func showBanner() {
        let banner = """
        \(bold)═══════════════════════════════════════════════════════════════
                   Whisper Streaming Benchmark
        ═══════════════════════════════════════════════════════════════\(reset)

        """
        print(banner)
    }

    func showSection(_ title: String) {
        print("\n\(bold)───────────────────────────────────────────────────────────────\(reset)")
        print("\(bold)\(title)\(reset)")
        print("\(bold)───────────────────────────────────────────────────────────────\(reset)\n")
    }

    func showInfo(_ message: String) {
        print("\(cyan)\(message)\(reset)")
    }

    func showSuccess(_ message: String) {
        print("\(green)\(message)\(reset)")
    }

    func showWarning(_ message: String) {
        print("\(yellow)Warning: \(message)\(reset)")
    }

    func showError(_ message: String) {
        print("\(red)Error: \(message)\(reset)")
    }

    func showModelHeader(name: String, size: String) {
        print("\n\(bold)Testing Model:\(reset) \(name) (\(size))")
    }

    func showLoading(_ message: String) {
        print("\(message)...", terminator: "")
        fflush(stdout)
    }

    func showLoadingDone(duration: TimeInterval? = nil) {
        if let duration = duration {
            print(" Done (\(String(format: "%.1f", duration))s)")
        } else {
            print(" Done")
        }
    }

    func showTestInstructions(passage: String) {
        print("")
        showReferencePassage(passage)
        print("Press \(bold)ENTER\(reset) to start recording (minimum 20s, target 30s).")
        print("Press \(bold)ENTER\(reset) again to stop.\n")
    }

    /// Display the reference passage in a bordered box
    func showReferencePassage(_ passage: String) {
        let boxWidth = min(terminalWidth - 2, 70)  // Cap at 70 for readability
        let innerWidth = boxWidth - 4  // Account for border and padding

        let wrapped = wordWrap(passage, width: innerWidth)
        let lines = wrapped.components(separatedBy: "\n")

        // Top border
        print("┌" + String(repeating: "─", count: boxWidth - 2) + "┐")

        // Header
        let headerText = "\(bold)REFERENCE (read this aloud):\(reset)"
        let headerPadding = boxWidth - 32  // Account for ANSI codes
        print("│  \(headerText)" + String(repeating: " ", count: max(0, headerPadding)) + "│")
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

    func showRecordingStatus(seconds: Int) {
        let indicator = "\(red)●\(reset)"
        print("\(clearLine)\(cursorToStart)Recording... \(indicator) [\(String(format: "%02d", seconds / 60)):\(String(format: "%02d", seconds % 60))]", terminator: "")
        fflush(stdout)
    }

    func showRecordingStopped(duration: TimeInterval) {
        print("\n\nRecording stopped. Duration: \(String(format: "%.1f", duration)) seconds\n")
    }

    // MARK: - Review Phase

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
        if transcript.isEmpty {
            print("\(dim)(No transcription captured)\(reset)")
        } else {
            print(wordWrap(transcript, width: 65))
        }
        print("")

        print("\(dim)Compare the transcript to the reference above.\(reset)")
        print("\(dim)Press ENTER when ready to rate.\(reset)")
    }

    func waitForReviewComplete() {
        _ = readLine()
    }

    func showTranscriptionHeader() {
        print("\n\(bold)───────────────────────────────────────────────────────────────\(reset)")
        print("\(bold)Live Transcription:\(reset)")
        print("\(bold)───────────────────────────────────────────────────────────────\(reset)\n")
    }

    func updateTranscription(confirmed: String, unconfirmed: String) {
        // Clear previous transcription lines
        for _ in 0..<lastTranscriptionLines {
            print("\(cursorUp)\(clearLine)", terminator: "")
        }
        print(cursorToStart, terminator: "")

        // Build transcription display
        var output = confirmed
        if !unconfirmed.isEmpty {
            output += "\(dim)[\(unconfirmed)]\(reset)"
        }

        // Word wrap at ~65 characters
        let wrapped = wordWrap(output, width: 65)
        let lines = wrapped.components(separatedBy: "\n")
        lastTranscriptionLines = lines.count + 2  // +2 for note line and blank

        print(wrapped)
        print("\n\(dim)(Words in [brackets] are unconfirmed - may change)\(reset)")
        fflush(stdout)
    }

    func showTimingHeader() {
        print("\n\(bold)───────────────────────────────────────────────────────────────\(reset)")
        print("\(bold)Timing:\(reset)")
    }

    func updateTiming(chunk: ChunkTiming, verbose: Bool) {
        let ratioStr = String(format: "%.2fx", chunk.processingRatio)
        let status = chunk.isViable ? "\(green)+\(reset)" : "\(red)x\(reset)"

        if verbose {
            print("  Chunk \(chunk.chunkIndex): \(String(format: "%.1f", chunk.audioDuration))s audio -> \(String(format: "%.2f", chunk.processingTime))s process (\(ratioStr)) \(status)")
        }
    }

    func showTimingSummary(chunks: Int, avgRatio: Double) {
        print("  \(chunks) chunks processed, average ratio: \(String(format: "%.2fx", avgRatio))")
    }

    func promptYesNo(_ question: String, defaultYes: Bool = true) -> Bool {
        let prompt = defaultYes ? "[Y/n]" : "[y/N]"
        print("\(question) \(prompt): ", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.lowercased() else {
            return defaultYes
        }

        if input.isEmpty {
            return defaultYes
        }

        return input == "y" || input == "yes"
    }

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

    func waitForEnter() {
        _ = readLine()
    }

    func showModelResults(metrics: ModelMetrics) {
        let status = metrics.viabilityStatus
        let statusColor = status == .viable ? green : (status == .marginal ? yellow : red)
        let statusSymbol = status == .viable ? "+" : (status == .marginal ? "~" : "x")

        print("\n\(bold)Results for \(metrics.modelName):\(reset)")
        print("  |-- Average Processing Ratio: \(String(format: "%.2fx", metrics.averageProcessingRatio)) realtime")
        print("  |-- First-Word Latency: \(String(format: "%.1f", metrics.firstWordLatency)) seconds")
        print("  |-- Backpressure Events: \(metrics.backpressureEvents)")
        print("  |-- Compute Unit: \(metrics.computeUnit.displayName)")
        let ratingDisplay = metrics.userQualityRating == .skipped
            ? "Skipped"
            : "\(metrics.userQualityRating.rawValue)/5 (\(metrics.userQualityRating.description))"
        print("  `-- User Quality Rating: \(ratingDisplay)")
        print("")
        print("  \(statusColor)[\(statusSymbol)] STREAMING \(status.displayString.uppercased())\(reset)")
    }

    func showFinalReport(results: [ModelMetrics], systemInfo: SystemInfo) {
        print("\n\(bold)═══════════════════════════════════════════════════════════════\(reset)")
        print("\(bold)           Whisper Streaming Benchmark Results\(reset)")
        print("\(bold)═══════════════════════════════════════════════════════════════\(reset)\n")

        print("Machine: \(systemInfo.displayString)")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("Date:    \(dateFormatter.string(from: Date()))\n")

        // Table header
        print("+---------------------+----------+-----------+--------+----------------+")
        print("| Model               | Ratio    | Latency   |Compute | Status         |")
        print("+---------------------+----------+-----------+--------+----------------+")

        for result in results {
            let status = result.viabilityStatus
            let statusColor = status == .viable ? green : (status == .marginal ? yellow : red)
            let statusSymbol = status == .viable ? "+" : (status == .marginal ? "~" : "x")

            let modelPadded = result.modelName.padding(toLength: 19, withPad: " ", startingAt: 0)
            let ratioPadded = String(format: "%.2fx", result.averageProcessingRatio).padding(toLength: 8, withPad: " ", startingAt: 0)
            let latencyPadded = String(format: "%.1fs", result.firstWordLatency).padding(toLength: 9, withPad: " ", startingAt: 0)
            let computePadded = result.computeUnit.displayName.padding(toLength: 6, withPad: " ", startingAt: 0)
            let statusPadded = "\(statusColor)[\(statusSymbol)] \(status.displayString)\(reset)".padding(toLength: 14 + statusColor.count + reset.count, withPad: " ", startingAt: 0)

            print("| \(modelPadded) | \(ratioPadded) | \(latencyPadded) | \(computePadded) | \(statusPadded) |")
        }

        print("+---------------------+----------+-----------+--------+----------------+\n")

        // Legend
        print("\(dim)Legend:\(reset)")
        print("  Ratio    = processing_time / audio_duration (< 1.0 required for streaming)")
        print("  Latency  = time from recording start to first word displayed")
        print("  Compute  = ANE (Neural Engine) or GPU")
        print("  Viable   = ratio < 1.0, latency < 3.0s, zero backpressure")
        print("  Marginal = ratio 1.0-1.5x, may work for slow/deliberate speech")
        print("  Not Viable = ratio > 1.5x, causes audio backlog\n")

        // Recommendation
        let viableModels = results.filter { $0.viabilityStatus == .viable }
        let marginalModels = results.filter { $0.viabilityStatus == .marginal }

        print("\(bold)Recommendation:\(reset)")
        if let bestViable = viableModels.last {
            print("  For real-time streaming on this hardware, use \(bestViable.modelName) or smaller.")
        } else if let bestMarginal = marginalModels.first {
            print("  No models are fully streaming-viable. \(bestMarginal.modelName) may work for slow speech.")
        } else {
            print("  No models tested are suitable for streaming on this hardware.")
        }

        if !marginalModels.isEmpty {
            print("  Marginal models may work for slow, deliberate dictation.")
        }

        let nonViable = results.filter { $0.viabilityStatus == .notViable }
        if !nonViable.isEmpty {
            let names = nonViable.map { $0.modelName }.joined(separator: ", ")
            print("  \(names) should only be used in batch (non-streaming) mode.")
        }
    }

    // MARK: - Helpers

    private func wordWrap(_ text: String, width: Int) -> String {
        var result = ""
        var currentLine = ""

        // Handle ANSI codes - we need to track them but not count them for width
        let words = text.components(separatedBy: " ")

        for word in words {
            let testLine = currentLine.isEmpty ? word : currentLine + " " + word
            let visibleLength = stripAnsiCodes(testLine).count

            if visibleLength > width && !currentLine.isEmpty {
                result += currentLine + "\n"
                currentLine = word
            } else {
                currentLine = testLine
            }
        }

        if !currentLine.isEmpty {
            result += currentLine
        }

        return result
    }

    private func stripAnsiCodes(_ text: String) -> String {
        // Remove ANSI escape sequences for length calculation
        let pattern = "\u{001B}\\[[0-9;]*[a-zA-Z]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }
}
