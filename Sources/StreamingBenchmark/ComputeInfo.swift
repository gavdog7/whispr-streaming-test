import Foundation
import Metal

enum ComputeUnit: String, Codable {
    case neuralEngine = "ANE"
    case gpu = "GPU"
    case cpu = "CPU"
    case unknown = "Unknown"

    var displayName: String {
        rawValue
    }
}

/// Detects and reports compute unit information
struct ComputeInfo {
    /// Attempts to determine which compute unit WhisperKit is using
    /// Note: WhisperKit automatically selects the optimal compute unit
    /// This is informational only - we can't force a specific unit
    static func detectComputeUnit(for modelName: String) -> ComputeUnit {
        // WhisperKit uses Neural Engine (ANE) for smaller models when available
        // and falls back to GPU for larger models or when ANE is saturated

        // Check if Metal is available (required for GPU)
        guard MTLCreateSystemDefaultDevice() != nil else {
            return .cpu
        }

        // Heuristic based on model size and typical WhisperKit behavior:
        // - tiny, base, small: Usually run on ANE
        // - medium: May use ANE or GPU depending on hardware
        // - large: Usually requires GPU due to size

        let lowercasedModel = modelName.lowercased()

        if lowercasedModel.contains("large") {
            return .gpu
        } else if lowercasedModel.contains("medium") {
            // Medium is borderline - report as GPU since it often spills over
            return .gpu
        } else {
            // tiny, base, small typically fit on ANE
            return .neuralEngine
        }
    }

    /// Get system information for the report
    static func systemInfo() -> SystemInfo {
        var size = 0
        sysctlbyname("hw.memsize", nil, &size, nil, 0)
        var memsize: UInt64 = 0
        sysctlbyname("hw.memsize", &memsize, &size, nil, 0)

        let ramGB = Double(memsize) / (1024 * 1024 * 1024)

        // Get machine model
        size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let machineModel = String(cString: model)

        // Get chip name (Apple Silicon)
        var chipName = "Unknown"
        size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var brand = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
            chipName = String(cString: brand)
        }

        // Get macOS version
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

        return SystemInfo(
            machineModel: machineModel,
            chipName: chipName,
            ramGB: ramGB,
            macOSVersion: osVersionString
        )
    }
}

struct SystemInfo: Codable {
    let machineModel: String
    let chipName: String
    let ramGB: Double
    let macOSVersion: String

    var displayString: String {
        let ramFormatted = String(format: "%.0f", ramGB)
        return "\(machineModel) (\(ramFormatted)GB RAM), macOS \(macOSVersion)"
    }
}
