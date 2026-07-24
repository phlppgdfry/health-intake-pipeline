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
            VStack(alignment: .leading, spacing: 20) {
                Label("Your personal advice", systemImage: "heart.text.square.fill")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)

                Text(advice.summary)
                    .font(.body)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(advice.recommendations.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.callout.bold())
                                .frame(width: 26, height: 26)
                                .background(.tint.opacity(0.15), in: Circle())
                            Text(item)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                Text("This demo generates mock advice. In a real product this screen is fed by the clinical engine and its sign-off workflow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func statusCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(title).font(.title3.bold())
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .accessibilityElement(children: .combine)
    }
}
