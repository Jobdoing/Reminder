import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testPauseKeepsCommittedTextWhenSpeechResumes() {
    var transcript = SpeechTranscriptAccumulator()
    transcript.updatePartial("first segment")
    transcript.commitCurrent()
    transcript.updatePartial("second segment")

    XCTAssertEqual(transcript.fullText, "first segmentsecond segment")
  }

  func testSessionGateRejectsRestartFromAnInvalidatedSession() {
    var gate = SpeechSessionGate()
    let token = gate.beginSession()

    XCTAssertTrue(gate.scheduleRestart(for: token))
    XCTAssertFalse(gate.scheduleRestart(for: token))
    gate.invalidate()

    XCTAssertFalse(gate.consumeRestart(for: token))
  }

  func testStartGateRejectsAuthorizationAfterStop() {
    var gate = SpeechStartGate()
    let token = gate.begin()

    gate.cancel()

    XCTAssertFalse(gate.isCurrent(token))
  }
}
