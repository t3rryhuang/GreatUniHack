import SwiftUI

/// The piggy bank, drawn with SwiftUI shapes. Coins fill it up to the teen's
/// progress to their own goal and jump when it's shaken.
struct PigView: View {
    let progress: Double
    let shakeCount: Int
    let tier: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let reduce = reduceMotion
        ZStack {
            pig
        }
        .frame(width: 260, height: 210)
        .keyframeAnimator(initialValue: Wobble(), trigger: shakeCount) { content, value in
            content
                .rotationEffect(.degrees(reduce ? 0 : value.angle))
                .offset(y: reduce ? 0 : value.lift)
                .opacity(reduce ? value.fade : 1)
        } keyframes: { _ in
            KeyframeTrack(\.angle) {
                for index in 0..<(3 + tier) {
                    SpringKeyframe(index.isMultiple(of: 2) ? Double(4 + tier * 2) : -Double(4 + tier * 2), duration: 0.09)
                }
                SpringKeyframe(0, duration: 0.2)
            }
            KeyframeTrack(\.lift) {
                CubicKeyframe(-8, duration: 0.12)
                SpringKeyframe(0, duration: 0.4)
            }
            KeyframeTrack(\.fade) {
                LinearKeyframe(0.55, duration: 0.2)
                LinearKeyframe(1, duration: 0.4)
            }
        }
        .accessibilityHidden(true)
    }

    private struct Wobble {
        var angle = 0.0
        var lift = 0.0
        var fade = 1.0
    }

    private var pig: some View {
        let pink = NovaColor.pastelPink
        let line = NovaColor.chartWatermelon
        return ZStack {
            // Tail
            Path { p in
                p.move(to: CGPoint(x: 26, y: 100))
                p.addCurve(to: CGPoint(x: 6, y: 86), control1: CGPoint(x: 10, y: 110), control2: CGPoint(x: 0, y: 96))
                p.addCurve(to: CGPoint(x: 18, y: 78), control1: CGPoint(x: 10, y: 76), control2: CGPoint(x: 16, y: 74))
            }
            .stroke(line, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            // Legs
            ForEach([62.0, 96.0, 164.0, 198.0], id: \.self) { x in
                Capsule().fill(pink).overlay(Capsule().strokeBorder(line, lineWidth: 3))
                    .frame(width: 26, height: 40)
                    .position(x: x, y: 178)
            }
            // Ear
            Path { p in
                p.move(to: CGPoint(x: 160, y: 46))
                p.addLine(to: CGPoint(x: 182, y: 14))
                p.addLine(to: CGPoint(x: 194, y: 54))
                p.closeSubpath()
            }
            .fill(pink)
            .overlay(Path { p in
                p.move(to: CGPoint(x: 160, y: 46)); p.addLine(to: CGPoint(x: 182, y: 14)); p.addLine(to: CGPoint(x: 194, y: 54))
            }.stroke(line, style: StrokeStyle(lineWidth: 3, lineJoin: .round)))
            // Body with coins inside
            ZStack(alignment: .bottom) {
                Ellipse().fill(pink)
                coins
                    .frame(height: 150 * min(1, max(0.06, progress)), alignment: .bottom)
                    .clipped()
            }
            .frame(width: 220, height: 150)
            .clipShape(Ellipse())
            .overlay(Ellipse().strokeBorder(line, lineWidth: 4))
            .position(x: 128, y: 104)
            // Coin slot
            Capsule().fill(line.opacity(0.85)).frame(width: 48, height: 8).position(x: 118, y: 36)
            // Snout
            Ellipse().fill(pink).overlay(Ellipse().strokeBorder(line, lineWidth: 3))
                .frame(width: 50, height: 42)
                .position(x: 236, y: 108)
            HStack(spacing: 8) {
                Capsule().fill(line).frame(width: 7, height: 13)
                Capsule().fill(line).frame(width: 7, height: 13)
            }
            .position(x: 236, y: 108)
            // Eye
            Circle().fill(NovaColor.heading).frame(width: 11, height: 11).position(x: 196, y: 78)
        }
        .frame(width: 260, height: 210)
    }

    /// Rows of coins up to the fill level; they hop a little on each shake.
    private var coins: some View {
        let filled = Color(light: 0xF2B705, dark: 0xFDD166)
        let reduce = reduceMotion
        return ZStack(alignment: .bottom) {
            Rectangle().fill(filled.opacity(0.28))
            VStack(spacing: -6) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: -4) {
                        ForEach(0..<12, id: \.self) { column in
                            Circle()
                                .fill(filled)
                                .overlay(Circle().strokeBorder(Color(light: 0xB37F00, dark: 0x9E7207), lineWidth: 1.5))
                                .frame(width: 22, height: 22)
                                .keyframeAnimator(initialValue: 0.0, trigger: shakeCount) { coin, hop in
                                    coin.offset(y: reduce ? 0 : hop)
                                } keyframes: { _ in
                                    CubicKeyframe(-Double(6 + (row + column) % 4 * 3 + tier * 2), duration: 0.12 + Double(column % 3) * 0.03)
                                    SpringKeyframe(0, duration: 0.35)
                                }
                        }
                    }
                }
            }
        }
    }
}
