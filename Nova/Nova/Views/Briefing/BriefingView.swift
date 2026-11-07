import SwiftUI

/// Full-screen morning briefing with voice playback. Ported from briefing.tsx.
struct BriefingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var briefing: MorningBriefing?
    @State private var showLocked = false

    var body: some View {
        let voice = model.services.voice
        ZStack {
            NovaColor.brandBand.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack {
                        NatWestMark(size: 40)
                        Spacer()
                        Button {
                            voice.stopSpeaking()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .frame(width: 44, height: 44)
                                .background(.white.opacity(0.18), in: Circle())
                        }
                        .accessibilityLabel("Close")
                    }
                    if let briefing {
                        Text(briefing.greeting).font(.largeTitle.weight(.semibold))
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: briefing.weather.condition.symbol)
                                .symbolRenderingMode(.multicolor)
                                .font(.largeTitle)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading) {
                                Text("\(briefing.weather.temperatureC)°C, \(briefing.weather.condition.label)").font(.novaSection)
                                Text(briefing.weather.city).font(.novaCallout).opacity(0.8)
                            }
                        }
                        .accessibilityElement(children: .combine)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Expected spend today").font(.novaCallout).opacity(0.8)
                            Text(briefing.expectedSpend.gbp).font(.system(size: 52, weight: .semibold)).monospacedDigit()
                                .minimumScaleFactor(0.6)
                        }
                        .accessibilityElement(children: .combine)

                        if let top = briefing.topPrediction {
                            briefingRow(icon: top.category.symbol, title: "Most likely", text: "\(top.title), \(top.probability.percent) likely, about \(top.amount.gbp)")
                        }
                        briefingRow(icon: "lightbulb.fill", title: "Today's nudge", text: briefing.nudge)
                        briefingRow(icon: "cloud.sun.fill", title: "Weather effect", text: briefing.weather.spendingImpact)

                        VStack(spacing: Spacing.md) {
                            SoundWave(isActive: voice.isSpeaking, tint: .white)
                            Button {
                                guard model.isPro else { showLocked = true; return }
                                if voice.isSpeaking { voice.stopSpeaking() } else { voice.speak(briefing.script) }
                            } label: {
                                Label(voice.isSpeaking ? "Pause briefing" : "Play briefing",
                                      systemImage: voice.isSpeaking ? "pause.fill" : "play.fill")
                            }
                            .buttonStyle(.novaInverse)
                        }
                        .padding(.top, Spacing.md)
                    } else {
                        ProgressView().tint(.white).frame(maxWidth: .infinity, minHeight: 300)
                    }
                }
                .padding(Spacing.lg)
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .task {
            briefing = try? await model.services.insights.briefing(from: model.transactions, name: model.user?.firstName ?? "there")
        }
        .onDisappear { voice.stopSpeaking() }
        .sheet(isPresented: $showLocked) {
            UpgradeView()
        }
    }

    private func briefingRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon).font(.title3).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.novaCaption.weight(.semibold)).opacity(0.8)
                Text(text).font(.novaBody).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
