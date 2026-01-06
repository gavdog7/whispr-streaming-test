import Foundation

/// Generates and exports benchmark results
@MainActor
class ResultsReporter {
    private let display: TerminalDisplay

    init(display: TerminalDisplay) {
        self.display = display
    }

    /// Show the final report in the terminal
    func showReport(results: [ModelMetrics]) {
        let systemInfo = ComputeInfo.systemInfo()
        display.showFinalReport(results: results, systemInfo: systemInfo)
    }

    /// Save results to JSON
    func saveJSON(results: [ModelMetrics], to path: String) throws {
        let report = BenchmarkReport(
            timestamp: Date(),
            systemInfo: ComputeInfo.systemInfo(),
            results: results.map { ResultEntry(from: $0) }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(report)

        // Ensure directory exists
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try data.write(to: url)
    }
}

// MARK: - JSON Models

struct BenchmarkReport: Codable {
    let timestamp: Date
    let systemInfo: SystemInfo
    let results: [ResultEntry]
}

struct ResultEntry: Codable {
    let modelName: String
    let totalAudioDuration: Double
    let totalProcessingTime: Double
    let averageProcessingRatio: Double
    let firstWordLatency: Double
    let backpressureEvents: Int
    let computeUnit: String
    let viabilityStatus: String
    let userQualityRating: Int
    let userQualityRatingDescription: String
    let chunkTimings: [ChunkTimingEntry]

    init(from metrics: ModelMetrics) {
        self.modelName = metrics.modelName
        self.totalAudioDuration = metrics.totalAudioDuration.isFinite ? metrics.totalAudioDuration : -1
        self.totalProcessingTime = metrics.totalProcessingTime.isFinite ? metrics.totalProcessingTime : -1
        self.averageProcessingRatio = metrics.averageProcessingRatio.isFinite ? metrics.averageProcessingRatio : -1
        self.firstWordLatency = metrics.firstWordLatency.isFinite ? metrics.firstWordLatency : -1
        self.backpressureEvents = metrics.backpressureEvents
        self.computeUnit = metrics.computeUnit.rawValue
        self.viabilityStatus = metrics.viabilityStatus.rawValue
        self.userQualityRating = metrics.userQualityRating.rawValue
        self.userQualityRatingDescription = metrics.userQualityRating.description
        self.chunkTimings = metrics.chunkTimings.map { ChunkTimingEntry(from: $0) }
    }
}

struct ChunkTimingEntry: Codable {
    let chunkIndex: Int
    let audioDuration: Double
    let processingTime: Double
    let processingRatio: Double
    let hadBackpressure: Bool

    init(from timing: ChunkTiming) {
        self.chunkIndex = timing.chunkIndex
        self.audioDuration = timing.audioDuration
        self.processingTime = timing.processingTime
        self.processingRatio = timing.processingRatio
        self.hadBackpressure = timing.hadBackpressure
    }
}
