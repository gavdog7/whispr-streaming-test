import ArgumentParser
import Foundation

@main
struct StreamingBenchmark: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "streaming-benchmark",
        abstract: "Benchmark Whisper models for streaming transcription viability",
        discussion: """
            Tests Whisper models from smallest to largest, measuring processing ratio,
            latency, and backpressure to determine which models can support real-time
            streaming transcription on your hardware.

            Models are tested in order: tiny, base, small, medium, large-v3

            Models must be pre-downloaded before running. See README for download instructions.
            """
    )

    @Option(name: .long, help: "Test only a specific model (e.g., openai_whisper-small)")
    var model: String?

    @Flag(name: .long, help: "Skip warmup phase (for debugging)")
    var skipWarmup = false

    @Option(name: .long, help: "Custom JSON output path")
    var output: String?

    @Flag(name: .long, help: "Show detailed timing for each chunk")
    var verbose = false

    func run() async throws {
        // Run on main actor
        try await runBenchmark(
            model: model,
            skipWarmup: skipWarmup,
            output: output,
            verbose: verbose
        )
    }

    @MainActor
    private func runBenchmark(
        model: String?,
        skipWarmup: Bool,
        output: String?,
        verbose: Bool
    ) async throws {
        let display = TerminalDisplay()

        display.showBanner()

        // Check microphone permission
        let audioCapture = AudioCapture()
        guard await audioCapture.requestPermission() else {
            display.showError("Microphone permission denied")
            display.showInfo("""
                To grant microphone access:
                1. Open System Settings > Privacy & Security > Microphone
                2. Enable access for Terminal.app (or your terminal emulator)
                3. Re-run this tool
                """)
            throw ExitCode(1)
        }

        // Determine output path
        let outputPath = output ?? defaultOutputPath()

        // Create benchmark runner
        let runner = BenchmarkRunner(
            display: display,
            audioCapture: audioCapture,
            skipWarmup: skipWarmup,
            verbose: verbose,
            singleModel: model
        )

        // Run benchmarks
        let results = try await runner.run()

        // Generate and display report
        let reporter = ResultsReporter(display: display)
        reporter.showReport(results: results)

        // Save results to JSON
        try reporter.saveJSON(results: results, to: outputPath)
        display.showSuccess("Results saved to: \(outputPath)")
    }

    private func defaultOutputPath() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("whisper-streaming-benchmark-\(dateString).json").path
    }
}
