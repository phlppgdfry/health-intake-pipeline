import SwiftUI

struct AdviceView: View {
    @EnvironmentObject private var flow: AppFlow

    enum State {
        case loading
        case queuedOffline
        case withheld
        case released(SignOffGate.ReleasedAdvice)
    }

    @SwiftUI.State private var state: State = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Preparing your advice…")
                    .tint(Theme.primary)
                    .foregroundStyle(Theme.inkSoft)
                    .accessibilityLabel("Preparing your advice")
            case .queuedOffline:
                statusCard(icon: "wifi.slash",
                           title: "You're offline",
                           message: "Your intake is saved on this device and will be sent automatically once you're back online.")
            case .withheld:
                statusCard(icon: "checkmark.shield",
                           title: "Almost there",
                           message: "Your advice is being reviewed. It becomes visible only after clinical sign-off.")
            case .released(let advice):
                releasedView(advice)
            }
        }
        .themedScreen()
        .navigationTitle("Advice")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let capture = flow.capture else {
            state = .withheld
            return
        }
        let request = AdviceRequest(answers: flow.intakeAnswers,
                                    scanSharpness: capture.quality.sharpness)
        switch await flow.engine.advice(for: request) {
        case .queuedOffline:
            state = .queuedOffline
        case .advice(let response):
            switch SignOffGate.evaluate(response) {
            case .released(let advice): state = .released(advice)
            case .withheld: state = .withheld
            }
        }
    }

    private func releasedView(_ advice: SignOffGate.ReleasedAdvice) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Your personal advice", systemImage: "heart.text.square.fill")
                        .font(.system(.title2, design: .serif).bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(advice.summary)
                        .font(.callout)
                        .opacity(0.95)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Theme.primary.opacity(0.3), radius: 14, y: 6)

                Text("Recommendations")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .textCase(.uppercase)
                    .padding(.top, 4)

                VStack(spacing: 12) {
                    ForEach(Array(advice.recommendations.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)")
                                .font(.callout.bold())
                                .foregroundStyle(Theme.primary)
                                .frame(width: 30, height: 30)
                                .background(Theme.primary.opacity(0.12), in: Circle())
                            Text(item)
                                .font(.body)
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .card()
                        .accessibilityElement(children: .combine)
                    }
                }

                Text("This demo generates mock advice. In a real product this screen is fed by the clinical engine and its sign-off workflow.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 6)
            }
            .padding(20)
        }
    }

    private func statusCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 76, height: 76)
                .background(Theme.primary.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.title3, design: .serif).bold())
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.callout)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .card()
        .padding(24)
        .accessibilityElement(children: .combine)
    }
}
