import Foundation

/// Timing information for a single audio chunk
struct ChunkTiming {
    let chunkIndex: Int
    let audioDuration: TimeInterval
    let processingTime: TimeInterval
    let processingRatio: Double
    let hadBackpressure: Bool
    let timestamp: Date

    var isViable: Bool {
        processingRatio < 1.0
    }
}

/// Aggregated metrics for a model test
struct ModelMetrics {
    let modelName: String
    let totalAudioDuration: TimeInterval
    let totalProcessingTime: TimeInterval
    let averageProcessingRatio: Double
    let firstWordLatency: TimeInterval
    let backpressureEvents: Int
    let computeUnit: ComputeUnit
    let chunkTimings: [ChunkTiming]
    let userQualityRating: QualityRating

    var isStreamingViable: Bool {
        averageProcessingRatio < 1.0 &&
        firstWordLatency < 3.0 &&
        backpressureEvents == 0 &&
        userQualityRating.rawValue >= QualityRating.fair.rawValue
    }

    var viabilityStatus: ViabilityStatus {
        if isStreamingViable {
            return .viable
        } else if averageProcessingRatio < 1.5 {
            return .marginal
        } else {
            return .notViable
        }
    }
}

enum ViabilityStatus: String, Codable {
    case viable = "viable"
    case marginal = "marginal"
    case notViable = "not_viable"

    var displayString: String {
        switch self {
        case .viable: return "Viable"
        case .marginal: return "Marginal"
        case .notViable: return "Not Viable"
        }
    }

    var emoji: String {
        switch self {
        case .viable: return "+"      // Will be styled green
        case .marginal: return "~"    // Will be styled yellow
        case .notViable: return "x"   // Will be styled red
        }
    }
}

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

/// Collector for timing metrics during a test
@MainActor
class MetricsCollector {
    private var chunkTimings: [ChunkTiming] = []
    private var testStartTime: Date?
    private var firstWordTime: Date?
    private var pendingChunks: Int = 0
    private let maxPendingChunks = 2

    var backpressureEvents: Int = 0

    func startTest() {
        testStartTime = Date()
        chunkTimings = []
        firstWordTime = nil
        pendingChunks = 0
        backpressureEvents = 0
    }

    func recordFirstWord() {
        if firstWordTime == nil {
            firstWordTime = Date()
        }
    }

    func chunkStarted() {
        pendingChunks += 1
        if pendingChunks > maxPendingChunks {
            backpressureEvents += 1
        }
    }

    func recordChunk(
        index: Int,
        audioDuration: TimeInterval,
        processingTime: TimeInterval
    ) {
        pendingChunks = max(0, pendingChunks - 1)

        let ratio = processingTime / audioDuration
        let timing = ChunkTiming(
            chunkIndex: index,
            audioDuration: audioDuration,
            processingTime: processingTime,
            processingRatio: ratio,
            hadBackpressure: pendingChunks >= maxPendingChunks,
            timestamp: Date()
        )
        chunkTimings.append(timing)
    }

    var latestChunkTiming: ChunkTiming? {
        chunkTimings.last
    }

    func finalize(modelName: String, computeUnit: ComputeUnit, qualityRating: QualityRating) -> ModelMetrics {
        let totalAudio = chunkTimings.reduce(0) { $0 + $1.audioDuration }
        let totalProcessing = chunkTimings.reduce(0) { $0 + $1.processingTime }
        let avgRatio = totalAudio > 0 ? totalProcessing / totalAudio : 0

        let firstWordLatency: TimeInterval
        if let start = testStartTime, let firstWord = firstWordTime {
            firstWordLatency = firstWord.timeIntervalSince(start)
        } else {
            firstWordLatency = .infinity
        }

        return ModelMetrics(
            modelName: modelName,
            totalAudioDuration: totalAudio,
            totalProcessingTime: totalProcessing,
            averageProcessingRatio: avgRatio,
            firstWordLatency: firstWordLatency,
            backpressureEvents: backpressureEvents,
            computeUnit: computeUnit,
            chunkTimings: chunkTimings,
            userQualityRating: qualityRating
        )
    }
}
