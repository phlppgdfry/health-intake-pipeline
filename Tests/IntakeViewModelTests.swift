import XCTest
@testable import HealthIntake

@MainActor
final class IntakeViewModelTests: XCTestCase {
    private let questions = [
        IntakeQuestion(id: "q1", text: "One?", options: ["A", "B"]),
        IntakeQuestion(id: "q2", text: "Two?", options: ["C", "D"]),
    ]

    func testAnsweringAdvancesAndCompletes() {
        let model = IntakeViewModel(questions: questions)
        XCTAssertEqual(model.current.id, "q1")
        XCTAssertEqual(model.progress, 0)

        model.answer("A")
        XCTAssertEqual(model.current.id, "q2")
        XCTAssertFalse(model.isComplete)

        model.answer("D")
        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.answers, [
            IntakeAnswer(questionID: "q1", answer: "A"),
            IntakeAnswer(questionID: "q2", answer: "D"),
        ])
    }

    func testGoingBackKeepsAnswerAndAllowsRevision() {
        let model = IntakeViewModel(questions: questions)
        model.answer("A")
        model.goBack()
        XCTAssertEqual(model.current.id, "q1")
        XCTAssertEqual(model.selectedAnswer(for: model.current), "A")

        // Revising must replace, not duplicate.
        model.answer("B")
        XCTAssertEqual(model.answers.filter { $0.questionID == "q1" }.count, 1)
        XCTAssertEqual(model.selectedAnswer(for: questions[0]), "B")
    }
}
