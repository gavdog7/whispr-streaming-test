import Foundation

/// Orchestrates the benchmark tests across models
@MainActor
class BenchmarkRunner {
    private let display: TerminalDisplay
    private let audioCapture: AudioCapture
    private let skipWarmup: Bool
    private let verbose: Bool
    private let singleModel: String?

    /// Models to test in order (smallest to largest)
    static let allModels: [(name: String, size: String)] = [
        ("openai_whisper-tiny", "39 MB"),
        ("openai_whisper-base", "74 MB"),
        ("openai_whisper-small", "244 MB"),
        ("openai_whisper-medium", "769 MB"),
        ("openai_whisper-large-v3", "1.5 GB")
    ]

    private let minimumRecordingDuration: TimeInterval = 20.0

    /// Track used passages to avoid repetition
    private var usedPassageIndices: Set<Int> = []

    init(
        display: TerminalDisplay,
        audioCapture: AudioCapture,
        skipWarmup: Bool,
        verbose: Bool,
        singleModel: String?
    ) {
        self.display = display
        self.audioCapture = audioCapture
        self.skipWarmup = skipWarmup
        self.verbose = verbose
        self.singleModel = singleModel
    }

    /// Run benchmarks and return results
    func run() async throws -> [ModelMetrics] {
        var results: [ModelMetrics] = []

        var modelsToTest: [(name: String, size: String)]

        if let single = singleModel {
            // Find the specified model
            if let model = Self.allModels.first(where: { $0.name == single || $0.name.contains(single) }) {
                modelsToTest = [model]
            } else {
                display.showError("Model '\(single)' not found")
                display.showInfo("Available models: \(Self.allModels.map { $0.name }.joined(separator: ", "))")
                throw BenchmarkError.modelNotFound(single)
            }
        } else {
            modelsToTest = Self.allModels
        }

        // Pre-download all models before testing
        let downloadResults = await downloadAllModels(models: modelsToTest.map { $0.name })

        // Filter to only successfully downloaded models
        modelsToTest = modelsToTest.filter { downloadResults[$0.name] == true }

        if modelsToTest.isEmpty {
            display.showError("No models available to test")
            throw BenchmarkError.noModelsAvailable
        }

        for (index, model) in modelsToTest.enumerated() {
            display.showModelHeader(name: model.name, size: model.size)

            // Test this model
            do {
                let metrics = try await testModel(name: model.name)
                results.append(metrics)
                display.showModelResults(metrics: metrics)
            } catch {
                display.showError("Failed to test \(model.name): \(error.localizedDescription)")

                // Create a failed metrics entry
                let failedMetrics = ModelMetrics(
                    modelName: model.name,
                    totalAudioDuration: 0,
                    totalProcessingTime: 0,
                    averageProcessingRatio: .infinity,
                    firstWordLatency: .infinity,
                    backpressureEvents: 0,
                    computeUnit: .unknown,
                    chunkTimings: [],
                    userQualityRating: .skipped
                )
                results.append(failedMetrics)
            }

            // Ask to continue if not the last model
            if index < modelsToTest.count - 1 {
                let nextModel = modelsToTest[index + 1]
                print("")
                if !display.promptYesNo("Continue to next model (\(nextModel.name))?") {
                    break
                }
            }
        }

        return results
    }

    /// Downloads all models that aren't already cached
    private func downloadAllModels(models: [String]) async -> [String: Bool] {
        display.showDownloadPhase(models: models)

        var results: [String: Bool] = [:]

        for (index, model) in models.enumerated() {
            let modelIndex = index + 1

            // Check if already downloaded
            let transcriber = LiveTranscriber(display: display, verbose: false)
            if await transcriber.modelExists(name: model) {
                display.showModelStatus(index: modelIndex, total: models.count,
                                       modelName: model, status: .alreadyDownloaded)
                results[model] = true
                continue
            }

            // Need to download - use WhisperKit's download mechanism
            display.showModelStatus(index: modelIndex, total: models.count,
                                   modelName: model, status: .downloading)

            do {
                // Download model files by loading then unloading
                _ = try await transcriber.loadModel(name: model)
                transcriber.unload()  // Free memory, files remain cached

                display.showModelStatus(index: modelIndex, total: models.count,
                                       modelName: model, status: .downloaded)
                results[model] = true
            } catch {
                display.showModelStatus(index: modelIndex, total: models.count,
                                       modelName: model, status: .failed(error.localizedDescription))
                results[model] = false
            }
        }

        let successful = results.values.filter { $0 }.count
        let failed = results.values.filter { !$0 }.count
        display.showDownloadComplete(successful: successful, failed: failed)

        return results
    }

    /// Test a single model
    private func testModel(name: String) async throws -> ModelMetrics {
        let transcriber = LiveTranscriber(display: display, verbose: verbose)
        let metricsCollector = MetricsCollector()

        // Check if model exists locally
        let available = transcriber.availableModels()
        if !available.contains(name) {
            display.showInfo("Model '\(name)' not found locally - will download...")
        }

        // Load model (WhisperKit will download if needed)
        display.showLoading("Loading model (downloading if needed)")
        let loadTime = try await transcriber.loadModel(name: name)
        display.showLoadingDone(duration: loadTime)

        // Warmup
        if !skipWarmup {
            display.showLoading("Running warmup (3 seconds)")
            try await transcriber.warmup()
            display.showLoadingDone()
        }

        // Select a passage for this test
        let (passageIndex, passage) = Passages.random(excluding: usedPassageIndices)
        usedPassageIndices.insert(passageIndex)

        // Show instructions with the selected passage
        display.showTestInstructions(passage: passage)

        // Wait for user to press Enter
        display.waitForEnter()

        // Start recording
        display.showTranscriptionHeader()
        transcriber.reset()

        var chunkIndex = 0

        // Set up callbacks
        transcriber.onFirstWord = {
            metricsCollector.recordFirstWord()
        }

        transcriber.onTranscriptionUpdate = { [display] confirmed, unconfirmed in
            display.updateTranscription(confirmed: confirmed, unconfirmed: unconfirmed)
        }

        // Set up audio chunk handling
        audioCapture.onChunkReady = { [weak self, transcriber, metricsCollector] samples in
            guard let self = self else { return }

            Task { @MainActor in
                metricsCollector.chunkStarted()
                let audioDuration = Double(samples.count) / self.audioCapture.sampleRate

                do {
                    let processingTime = try await transcriber.transcribeChunk(samples)
                    metricsCollector.recordChunk(
                        index: chunkIndex,
                        audioDuration: audioDuration,
                        processingTime: processingTime
                    )

                    if let timing = metricsCollector.latestChunkTiming {
                        self.display.updateTiming(chunk: timing, verbose: self.verbose)
                    }

                    chunkIndex += 1
                } catch {
                    self.display.showWarning("Chunk \(chunkIndex) failed: \(error.localizedDescription)")
                }
            }
        }

        metricsCollector.startTest()
        try audioCapture.startCapture()

        // Recording loop - update display every second
        var lastDuration: Int = 0
        while true {
            try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

            let duration = audioCapture.currentDuration
            let seconds = Int(duration)

            if seconds != lastDuration {
                display.showRecordingStatus(seconds: seconds)
                lastDuration = seconds
            }

            // Check for Enter key (non-blocking would be ideal, but for simplicity we check duration)
            // In a real implementation, we'd use a separate thread for input
            // For now, we'll use a fixed duration or require Ctrl+C

            // Check if minimum duration reached and user might want to stop
            if duration >= minimumRecordingDuration {
                // For this implementation, let's auto-stop at ~35 seconds
                // A proper implementation would use non-blocking stdin
                if duration >= 35 {
                    break
                }
            }
        }

        // Stop recording
        let totalDuration = audioCapture.stopCapture()
        display.showRecordingStopped(duration: totalDuration)

        // Process any remaining audio
        if let remaining = audioCapture.flushRemaining(), !remaining.isEmpty {
            _ = try? await transcriber.transcribeChunk(remaining)
        }

        // Get final transcript for review
        let finalTranscript = transcriber.fullTranscript

        // Show review phase
        display.showReviewPhase(passage: passage, transcript: finalTranscript)

        // Wait for user to finish reviewing
        display.waitForReviewComplete()

        // Get user quality assessment
        let quality = display.promptQuality()

        // Finalize metrics
        let computeUnit = ComputeInfo.detectComputeUnit(for: name)
        let metrics = metricsCollector.finalize(
            modelName: name,
            computeUnit: computeUnit,
            qualityRating: quality
        )

        // Cleanup
        transcriber.unload()

        return metrics
    }
}

enum BenchmarkError: Error, LocalizedError {
    case modelNotFound(String)
    case modelNotDownloaded(String)
    case noModelsAvailable
    case recordingTooShort
    case interrupted

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model '\(name)' not found"
        case .modelNotDownloaded(let name):
            return "Model '\(name)' is not downloaded"
        case .noModelsAvailable:
            return "No models available to test (all downloads failed)"
        case .recordingTooShort:
            return "Recording was too short (minimum 20 seconds required)"
        case .interrupted:
            return "Benchmark was interrupted"
        }
    }
}
