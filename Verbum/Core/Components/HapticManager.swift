import UIKit
import CoreHaptics

enum HapticManager {

    // MARK: - Engine

    private static var _engine: CHHapticEngine?
    private static var _engineRunning = false
    private static let lock = NSLock()

    private static var engine: CHHapticEngine? {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        lock.lock(); defer { lock.unlock() }
        if _engine == nil {
            _engine = try? CHHapticEngine()
            _engine?.isAutoShutdownEnabled = true
            _engine?.stoppedHandler = { _ in
                HapticManager.lock.lock()
                HapticManager._engine = nil
                HapticManager._engineRunning = false
                HapticManager.lock.unlock()
            }
            _engine?.resetHandler = {
                HapticManager.lock.lock()
                HapticManager._engineRunning = false
                try? HapticManager._engine?.start()
                HapticManager._engineRunning = true
                HapticManager.lock.unlock()
            }
            try? _engine?.start()
            _engineRunning = true
        }
        return _engine
    }

    // MARK: - Public API

    /// Smooth wave sensation for word swipes — soft arc, not a blunt tap
    static func swipeWave() {
        guard let engine else { UISelectionFeedbackGenerator().selectionChanged(); return }
        let events: [(t: Double, i: Float, s: Float)] = [
            (0.00, 0.10, 0.05),
            (0.04, 0.30, 0.10),
            (0.08, 0.55, 0.15),
            (0.12, 0.65, 0.15),
            (0.16, 0.45, 0.10),
            (0.20, 0.20, 0.05),
            (0.24, 0.05, 0.00),
        ]
        play(engine: engine, events: events)
    }

    /// Ascending triple-pulse for a correct quiz answer — feels rewarding
    static func correctAnswer() {
        guard let engine else { UINotificationFeedbackGenerator().notificationOccurred(.success); return }
        let events: [(t: Double, i: Float, s: Float)] = [
            (0.00, 0.25, 0.05),
            (0.13, 0.55, 0.15),
            (0.26, 0.90, 0.35),
        ]
        play(engine: engine, events: events)
    }

    /// Wrong answer — two sharp taps
    static func wrongAnswer() {
        guard let engine else { UINotificationFeedbackGenerator().notificationOccurred(.error); return }
        let events: [(t: Double, i: Float, s: Float)] = [
            (0.00, 0.80, 0.85),
            (0.14, 0.50, 0.60),
        ]
        play(engine: engine, events: events)
    }

    // MARK: - Legacy UIKit (kept for compatibility + non-haptic-engine fallback)

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func error() {
        wrongAnswer()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        correctAnswer()
    }

    // MARK: - Internal

    private static func play(engine: CHHapticEngine, events: [(t: Double, i: Float, s: Float)]) {
        let hapticEvents = events.map { ev -> CHHapticEvent in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: ev.i),
                    .init(parameterID: .hapticSharpness, value: ev.s),
                ],
                relativeTime: ev.t
            )
        }
        guard let pattern = try? CHHapticPattern(events: hapticEvents, parameters: []) else { return }
        do {
            lock.lock()
            let needsRestart = !_engineRunning
            lock.unlock()
            if needsRestart {
                try engine.start()
                lock.lock()
                _engineRunning = true
                lock.unlock()
            }
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            #if DEBUG
            print("[HapticManager] play failed: \(error)")
            #endif
        }
    }
}
