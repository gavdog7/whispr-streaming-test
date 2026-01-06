import Foundation
import WhisperKit

/// Wraps WhisperKit for streaming transcription with LocalAgreement-n confirmation
@MainActor
class LiveTranscriber {
    private var whisperKit: WhisperKit?
    private let display: TerminalDisplay
    private let verbose: Bool

    /// LocalAgreement-n parameters
    private let confirmationWindow = 3  // Number of consecutive chunks for confirmation
    private let unconfirmedTokenCount = 2  // Last n tokens are unconfirmed

    /// Token history for LocalAgreement confirmation
    private var tokenHistory: [[String]] = []
    private var confirmedText: String = ""
    private var unconfirmedText: String = ""

    /// Callbacks
    var onTranscriptionUpdate: ((String, String) -> Void)?  // (confirmed, unconfirmed)
    var onFirstWord: (() -> Void)?

    private var hasEmittedFirstWord = false

    init(display: TerminalDisplay, verbose: Bool) {
        self.display = display
        self.verbose = verbose
    }

    /// Load a Whisper model
    func loadModel(name: String) async throws -> TimeInterval {
        let startTime = Date()

        // Initialize WhisperKit with the specified model
        whisperKit = try await WhisperKit(
            model: name,
            verbose: verbose,
            prewarm: true
        )

        return Date().timeIntervalSince(startTime)
    }

    /// Check if a model exists locally
    func modelExists(name: String) async -> Bool {
        // WhisperKit stores models in ~/Library/Caches/com.argmax.whisperkit/
        // Check if the model directory exists
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let whisperKitDir = cacheDir.appendingPathComponent("com.argmax.whisperkit")
        let modelDir = whisperKitDir.appendingPathComponent(name)

        return FileManager.default.fileExists(atPath: modelDir.path)
    }

    /// Get available models
    func availableModels() -> [String] {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let whisperKitDir = cacheDir.appendingPathComponent("com.argmax.whisperkit")

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: whisperKitDir.path) else {
            return []
        }

        return contents.filter { $0.hasPrefix("openai_whisper-") }.sorted()
    }

    /// Run warmup inference
    func warmup() async throws {
        guard let whisper = whisperKit else {
            throw TranscriberError.modelNotLoaded
        }

        // Create a short silent audio buffer for warmup
        let sampleRate = 16000
        let duration = 1.0  // 1 second
        let samples = [Float](repeating: 0.0, count: Int(Double(sampleRate) * duration))

        // Run inference (result discarded)
        _ = try await whisper.transcribe(audioArray: samples)
    }

    /// Transcribe an audio chunk and update state
    func transcribeChunk(_ samples: [Float]) async throws -> TimeInterval {
        guard let whisper = whisperKit else {
            throw TranscriberError.modelNotLoaded
        }

        let startTime = Date()

        // Transcribe the chunk
        let results = try await whisper.transcribe(audioArray: samples)

        let processingTime = Date().timeIntervalSince(startTime)

        // Extract tokens from result
        if let result = results.first {
            let tokens = extractTokens(from: result)
            updateConfirmation(with: tokens)

            // Check for first word
            if !hasEmittedFirstWord && !confirmedText.isEmpty {
                hasEmittedFirstWord = true
                onFirstWord?()
            }

            // Notify of update
            onTranscriptionUpdate?(confirmedText, unconfirmedText)
        }

        return processingTime
    }

    /// Get the full accumulated transcript (confirmed + unconfirmed)
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

    /// Reset state for a new test
    func reset() {
        tokenHistory.removeAll()
        confirmedText = ""
        unconfirmedText = ""
        hasEmittedFirstWord = false
    }

    /// Unload the current model
    func unload() {
        whisperKit = nil
        reset()
    }

    // MARK: - LocalAgreement-n Implementation

    private func extractTokens(from result: TranscriptionResult) -> [String] {
        // Get text and split into words/tokens
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    }

    private func updateConfirmation(with newTokens: [String]) {
        // Add to history
        tokenHistory.append(newTokens)

        // Keep only recent history for confirmation window
        if tokenHistory.count > confirmationWindow {
            tokenHistory.removeFirst()
        }

        // Find confirmed tokens using LocalAgreement
        // A token is confirmed if it appears in the same position in `confirmationWindow` consecutive chunks
        var confirmed: [String] = []
        var unconfirmed: [String] = []

        guard let latestTokens = tokenHistory.last else { return }

        // For each token in the latest result
        for (index, token) in latestTokens.enumerated() {
            // Check if this token appears at this position in all recent chunks
            var appearsInAll = true

            if tokenHistory.count >= confirmationWindow {
                for i in 0..<confirmationWindow {
                    let historyIndex = tokenHistory.count - confirmationWindow + i
                    let historicalTokens = tokenHistory[historyIndex]

                    if index >= historicalTokens.count || historicalTokens[index] != token {
                        appearsInAll = false
                        break
                    }
                }
            } else {
                // Not enough history yet - nothing confirmed
                appearsInAll = false
            }

            if appearsInAll {
                confirmed.append(token)
            } else if index >= latestTokens.count - unconfirmedTokenCount {
                // Last n tokens are always unconfirmed
                unconfirmed.append(token)
            } else {
                // In the middle - tentatively confirmed but keep in unconfirmed display
                unconfirmed.append(token)
            }
        }

        // Update state
        // Confirmed text accumulates; we only add newly confirmed tokens
        let newConfirmedCount = confirmed.count
        let previousConfirmedCount = confirmedText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count

        if newConfirmedCount > previousConfirmedCount {
            let newlyConfirmed = confirmed.suffix(newConfirmedCount - previousConfirmedCount)
            if !confirmedText.isEmpty {
                confirmedText += " "
            }
            confirmedText += newlyConfirmed.joined(separator: " ")
        }

        unconfirmedText = unconfirmed.joined(separator: " ")
    }
}

enum TranscriberError: Error, LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model is loaded"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        }
    }
}
