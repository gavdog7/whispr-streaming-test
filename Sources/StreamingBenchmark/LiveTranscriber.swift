import Foundation
import WhisperKit

/// Wraps WhisperKit for streaming transcription using cumulative buffer approach
@MainActor
class LiveTranscriber {
    private var whisperKit: WhisperKit?
    private let display: TerminalDisplay
    private let verbose: Bool

    /// Accumulated audio buffer (all samples since recording started)
    private var audioBuffer: [Float] = []
    private let sampleRate: Double = 16000

    /// Maximum audio to transcribe at once (30 seconds)
    /// Longer recordings use a sliding window from the end
    private let maxTranscriptionDuration: TimeInterval = 30.0
    private var maxSamples: Int {
        Int(sampleRate * maxTranscriptionDuration)
    }

    /// Previous transcription for comparison
    private var previousTranscription: String = ""

    /// Current confirmed and unconfirmed text
    private var confirmedText: String = ""
    private var unconfirmedText: String = ""

    /// Number of trailing words to treat as unconfirmed (may still change)
    private let unconfirmedWordCount = 3

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

    /// Check if a model exists locally using WhisperKit's cache structure
    func modelExists(name: String) async -> Bool {
        // WhisperKit stores models in ~/Library/Caches/com.argmax.whisperkit/
        // Check both possible locations
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let whisperKitDir = cacheDir.appendingPathComponent("com.argmax.whisperkit")

        // Check direct path
        let directPath = whisperKitDir.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: directPath.path) {
            return true
        }

        // Check HuggingFace cache structure
        let hfPath = whisperKitDir
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models--argmaxinc--whisperkit-coreml")

        // Look for model in snapshots
        let snapshotsPath = hfPath.appendingPathComponent("snapshots")
        if let snapshots = try? FileManager.default.contentsOfDirectory(atPath: snapshotsPath.path) {
            for snapshot in snapshots {
                let modelPath = snapshotsPath.appendingPathComponent(snapshot).appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: modelPath.path) {
                    return true
                }
            }
        }

        return false
    }

    /// Get available models
    func availableModels() -> [String] {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let whisperKitDir = cacheDir.appendingPathComponent("com.argmax.whisperkit")

        var models: Set<String> = []

        // Check direct path
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: whisperKitDir.path) {
            for item in contents where item.hasPrefix("openai_whisper-") {
                models.insert(item)
            }
        }

        // Check HuggingFace cache structure
        let hfPath = whisperKitDir
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models--argmaxinc--whisperkit-coreml")
            .appendingPathComponent("snapshots")

        if let snapshots = try? FileManager.default.contentsOfDirectory(atPath: hfPath.path) {
            for snapshot in snapshots {
                let snapshotPath = hfPath.appendingPathComponent(snapshot)
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: snapshotPath.path) {
                    for item in contents where item.hasPrefix("openai_whisper-") {
                        models.insert(item)
                    }
                }
            }
        }

        return models.sorted()
    }

    /// Run warmup inference
    func warmup() async throws {
        guard let whisper = whisperKit else {
            throw TranscriberError.modelNotLoaded
        }

        // Create a short silent audio buffer for warmup
        let duration = 1.0  // 1 second
        let samples = [Float](repeating: 0.0, count: Int(sampleRate * duration))

        // Run inference (result discarded)
        _ = try await whisper.transcribe(audioArray: samples)
    }

    /// Add audio samples to the buffer and transcribe
    func transcribeChunk(_ samples: [Float]) async throws -> TimeInterval {
        guard let whisper = whisperKit else {
            throw TranscriberError.modelNotLoaded
        }

        // Accumulate audio
        audioBuffer.append(contentsOf: samples)

        // Get audio to transcribe (use sliding window if too long)
        let samplesToTranscribe: [Float]
        if audioBuffer.count > maxSamples {
            // Use last maxSamples for transcription
            samplesToTranscribe = Array(audioBuffer.suffix(maxSamples))
        } else {
            samplesToTranscribe = audioBuffer
        }

        // Skip if we don't have enough audio yet (at least 1 second)
        let minSamples = Int(sampleRate * 1.0)
        guard samplesToTranscribe.count >= minSamples else {
            return 0
        }

        let startTime = Date()

        // Transcribe the accumulated buffer
        let results = try await whisper.transcribe(audioArray: samplesToTranscribe)

        let processingTime = Date().timeIntervalSince(startTime)

        // Process result
        if let result = results.first {
            let newTranscription = cleanTranscription(result.text)
            updateConfirmedText(newTranscription: newTranscription)

            // Check for first word
            if !hasEmittedFirstWord && !confirmedText.isEmpty {
                hasEmittedFirstWord = true
                onFirstWord?()
            }

            // Notify of update
            onTranscriptionUpdate?(confirmedText, unconfirmedText)

            previousTranscription = newTranscription
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
        audioBuffer.removeAll()
        previousTranscription = ""
        confirmedText = ""
        unconfirmedText = ""
        hasEmittedFirstWord = false
    }

    /// Unload the current model
    func unload() {
        whisperKit = nil
        reset()
    }

    // MARK: - Private Helpers

    /// Clean up transcription text
    private func cleanTranscription(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common Whisper artifacts
        let artifacts = ["[BLANK_AUDIO]", "(BLANK_AUDIO)", "[MUSIC]", "(MUSIC)"]
        for artifact in artifacts {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "")
        }

        // Collapse multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    /// Update confirmed/unconfirmed text based on new transcription
    private func updateConfirmedText(newTranscription: String) {
        let newWords = newTranscription.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard !newWords.isEmpty else {
            unconfirmedText = ""
            return
        }

        // Compare with previous transcription to find stable prefix
        let previousWords = previousTranscription.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // Find how many words match from the start
        var matchingCount = 0
        for i in 0..<min(previousWords.count, newWords.count) {
            if previousWords[i].lowercased() == newWords[i].lowercased() {
                matchingCount = i + 1
            } else {
                break
            }
        }

        // Words that matched previous transcription are more stable
        // But always keep the last few words as "unconfirmed" since they may change
        let stableCount = max(0, min(matchingCount, newWords.count - unconfirmedWordCount))

        // Update confirmed text (only add newly confirmed words)
        let currentConfirmedWords = confirmedText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if stableCount > currentConfirmedWords.count {
            let newlyConfirmed = newWords[currentConfirmedWords.count..<stableCount]
            if !confirmedText.isEmpty && !newlyConfirmed.isEmpty {
                confirmedText += " "
            }
            confirmedText += newlyConfirmed.joined(separator: " ")
        }

        // Unconfirmed is everything after confirmed
        let confirmedWordCount = confirmedText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        if confirmedWordCount < newWords.count {
            unconfirmedText = newWords[confirmedWordCount...].joined(separator: " ")
        } else {
            unconfirmedText = ""
        }
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
