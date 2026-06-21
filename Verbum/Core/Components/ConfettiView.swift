import SwiftUI

/// Overlay confetti effect for celebration moments (goal hit, streak milestone, perfect quiz).
/// Particles fall under gravity with rotation. Auto-dismisses after `duration`.
struct ConfettiView: View {
    let duration: Double
    let particleCount: Int
    @State private var particles: [Particle] = []
    @State private var startTime = Date()

    init(duration: Double = 2.2, particleCount: Int = 80) {
        self.duration = duration
        self.particleCount = particleCount
    }

    private struct Particle: Identifiable {
        let id = UUID()
        let x: Double            // 0...1 horizontal start
        let dx: Double           // horizontal drift
        let size: Double
        let color: Color
        let delay: Double
        let rotationSpeed: Double
        let startVelocity: Double
    }

    private static let palette: [Color] = [
        Color(hex: "#6ECFCF"),
        Color(hex: "#FFB84D"),
        Color(hex: "#FF6B6B"),
        Color(hex: "#9B72FF"),
        Color.white
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(startTime)
                for p in particles {
                    let localT = t - p.delay
                    guard localT > 0 else { continue }
                    let progress = localT / duration
                    guard progress < 1.0 else { continue }
                    // Vertical fall with gravity
                    let g = 600.0
                    let y = -40 + p.startVelocity * localT + 0.5 * g * localT * localT
                    let x = p.x * size.width + p.dx * localT * 60
                    let rot = p.rotationSpeed * localT
                    let opacity = max(0, 1 - progress * 0.8)
                    let path = Path(roundedRect: CGRect(x: x - p.size / 2, y: y - p.size / 2, width: p.size, height: p.size * 0.4),
                                    cornerRadius: 1)
                    var transformed = path
                    transformed = transformed.applying(
                        CGAffineTransform(translationX: -x, y: -y)
                            .concatenating(CGAffineTransform(rotationAngle: rot))
                            .concatenating(CGAffineTransform(translationX: x, y: y))
                    )
                    context.fill(transformed, with: .color(p.color.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            particles = (0..<particleCount).map { _ in
                Particle(
                    x: Double.random(in: 0...1),
                    dx: Double.random(in: -1.5...1.5),
                    size: Double.random(in: 6...11),
                    color: Self.palette.randomElement() ?? .white,
                    delay: Double.random(in: 0...0.3),
                    rotationSpeed: Double.random(in: -6...6),
                    startVelocity: Double.random(in: 50...180)
                )
            }
            startTime = Date()
        }
    }
}
