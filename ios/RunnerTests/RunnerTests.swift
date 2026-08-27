import PaddleLAC
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testPaddleLACMatchesAndroidPersonCorpus() {
    let detector = PaddleLACPersonDetector()
    let cases: [(String, [String])] = [
      ("李佩瑜明天來", ["李佩瑜"]),
      ("叫李佩瑜來", ["李佩瑜"]),
      ("請李佩瑜提醒我", ["李佩瑜"]),
      ("陪李佩瑜吃飯", ["李佩瑜"]),
      ("明天跟李佩瑜吃飯", ["李佩瑜"]),
      ("提醒我明天下午要跟李佩瑜吃飯", ["李佩瑜"]),
      ("李沛米明天來", ["李沛米"]),
      ("今天買李子很好吃", ["李子"]),
      ("今天跟李子買水果", ["李子"]),
      ("提醒我明天下午吃飯", []),
    ]

    for (text, expected) in cases {
      XCTAssertEqual(detector.detectWords(text), expected, text)
    }
  }

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
