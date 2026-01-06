import AVFoundation
import Foundation

/// Handles microphone audio capture using AVFoundation
@MainActor
class AudioCapture {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    /// Buffer to accumulate audio samples
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    /// Callback for when a chunk is ready
    var onChunkReady: (([Float]) -> Void)?

    /// Configuration
    let sampleRate: Double = 16000  // WhisperKit requirement
    let chunkDuration: TimeInterval = 1.5  // seconds
    let chunkOverlap: TimeInterval = 0.25  // seconds

    private var samplesPerChunk: Int {
        Int(sampleRate * chunkDuration)
    }

    private var overlapSamples: Int {
        Int(sampleRate * chunkOverlap)
    }

    private var isRecording = false
    private var recordingStartTime: Date?

    /// Request microphone permission
    func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Start capturing audio
    func startCapture() throws {
        guard !isRecording else { return }

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw AudioCaptureError.engineInitFailed
        }

        inputNode = engine.inputNode

        // Get the native format and create converter if needed
        let inputFormat = inputNode!.outputFormat(forBus: 0)

        // Create our desired format (16kHz mono Float32)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.formatError
        }

        // Create converter if sample rates differ
        let converter: AVAudioConverter?
        if inputFormat.sampleRate != sampleRate {
            converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        } else {
            converter = nil
        }

        // Install tap on input node
        inputNode!.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        try engine.start()
        isRecording = true
        recordingStartTime = Date()
        audioBuffer.removeAll()
    }

    /// Stop capturing audio
    func stopCapture() -> TimeInterval {
        guard isRecording else { return 0 }

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isRecording = false

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartTime = nil
        return duration
    }

    /// Get current recording duration
    var currentDuration: TimeInterval {
        guard isRecording, let start = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Process incoming audio buffer
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter?, targetFormat: AVAudioFormat) {
        var samples: [Float]

        if let converter = converter {
            // Convert to target format
            guard let convertedBuffer = convertBuffer(buffer, converter: converter, targetFormat: targetFormat) else {
                return
            }
            samples = extractSamples(from: convertedBuffer)
        } else {
            samples = extractSamples(from: buffer)
        }

        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)

        // Check if we have enough for a chunk
        while audioBuffer.count >= samplesPerChunk {
            let chunk = Array(audioBuffer.prefix(samplesPerChunk))

            // Remove samples, keeping overlap
            let samplesToRemove = samplesPerChunk - overlapSamples
            audioBuffer.removeFirst(min(samplesToRemove, audioBuffer.count))

            bufferLock.unlock()

            // Notify listener on main thread
            Task { @MainActor in
                self.onChunkReady?(chunk)
            }

            bufferLock.lock()
        }
        bufferLock.unlock()
    }

    private func convertBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = UInt32(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            return nil
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if error != nil {
            return nil
        }

        return outputBuffer
    }

    private func extractSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        if channelCount == 1 {
            // Mono - just copy
            return Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        } else {
            // Stereo or more - mix to mono
            var monoSamples = [Float](repeating: 0, count: frameLength)
            for i in 0..<frameLength {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += channelData[ch][i]
                }
                monoSamples[i] = sum / Float(channelCount)
            }
            return monoSamples
        }
    }

    /// Get any remaining audio that hasn't formed a complete chunk
    func flushRemaining() -> [Float]? {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        guard !audioBuffer.isEmpty else { return nil }

        let remaining = audioBuffer
        audioBuffer.removeAll()
        return remaining
    }
}

enum AudioCaptureError: Error, LocalizedError {
    case engineInitFailed
    case formatError
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .engineInitFailed:
            return "Failed to initialize audio engine"
        case .formatError:
            return "Failed to create audio format"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}
