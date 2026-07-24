import SwiftUI

struct IntakeView: View {
    @EnvironmentObject private var flow: AppFlow
    @StateObject private var model = IntakeViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ProgressView(value: model.progress)
                .accessibilityLabel("Intake progress")
                .accessibilityValue("\(model.answers.count) of \(model.questions.count) questions answered")

            Text(model.current.text)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 10) {
                ForEach(model.current.options, id: \.self) { option in
                    Button {
                        model.answer(option)
                        if model.isComplete {
                            flow.intakeAnswers = model.answers
                            flow.step = .scan
                        }
                    } label: {
                        HStack {
                            Text(option)
                            Spacer()
                            if model.selectedAnswer(for: model.current) == option {
                                Image(systemName: "checkmark")
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }

            Spacer()

            if model.index > 0 {
                Button("Previous question") { model.goBack() }
                    .font(.callout)
            }
        }
        .padding()
        .navigationTitle("Intake")
        .navigationBarTitleDisplayMode(.inline)
    }
}
