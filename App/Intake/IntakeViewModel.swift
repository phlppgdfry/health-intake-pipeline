import Foundation

/// Drives the question-by-question intake flow as a small state machine:
/// answering advances, back rewinds without losing previous answers, and the
/// flow completes only when every question has an answer.
@MainActor
final class IntakeViewModel: ObservableObject {
    @Published private(set) var index = 0
    @Published private(set) var answers: [IntakeAnswer] = []

    let questions: [IntakeQuestion]

    init(questions: [IntakeQuestion] = IntakeQuestion.demoCatalog) {
        precondition(!questions.isEmpty, "Intake requires at least one question")
        self.questions = questions
    }

    var current: IntakeQuestion { questions[index] }
    var isComplete: Bool { answers.count == questions.count }
    var progress: Double { Double(answers.count) / Double(questions.count) }

    func selectedAnswer(for question: IntakeQuestion) -> String? {
        answers.first { $0.questionID == question.id }?.answer
    }

    func answer(_ option: String) {
        answers.removeAll { $0.questionID == current.id }
        answers.append(IntakeAnswer(questionID: current.id, answer: option))
        if index < questions.count - 1 {
            index += 1
        }
    }

    func goBack() {
        guard index > 0 else { return }
        index -= 1
    }
}
