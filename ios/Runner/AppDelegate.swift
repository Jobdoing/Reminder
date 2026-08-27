import AVFoundation
import Flutter
import PaddleLAC
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  let flutterEngine = FlutterEngine(name: "main")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard flutterEngine.run() else { return false }
    GeneratedPluginRegistrant.register(with: flutterEngine)
    if let registrar = flutterEngine.registrar(forPlugin: "SpeechChannel") {
      SpeechChannel.register(messenger: registrar.messenger())
      PaddleLACPersonSpanChannel.register(with: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Accumulates committed utterances plus the in-flight one, so a pause (which
/// ends an utterance) does not discard earlier text.
struct SpeechTranscriptAccumulator {
  private(set) var committed = ""
  private(set) var current = ""

  var fullText: String { joined(committed, current) }

  mutating func updatePartial(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { current = trimmed }
  }

  mutating func commitCurrent() {
    committed = joined(committed, current)
    current = ""
  }

  private func joined(_ earlier: String, _ later: String) -> String {
    let first = earlier.trimmingCharacters(in: .whitespacesAndNewlines)
    let second = later.trimmingCharacters(in: .whitespacesAndNewlines)
    if first.isEmpty { return second }
    if second.isEmpty { return first }
    return first + second
  }
}

/// Tracks recognition-session generations so stale task callbacks are ignored
/// and exactly one restart happens per finished session.
struct SpeechSessionGate {
  private var generation = 0
  private var restartGeneration: Int?

  mutating func beginSession() -> Int {
    generation += 1
    restartGeneration = nil
    return generation
  }

  mutating func invalidate() {
    generation += 1
    restartGeneration = nil
  }

  func isCurrent(_ token: Int) -> Bool { token == generation }

  mutating func scheduleRestart(for token: Int) -> Bool {
    guard isCurrent(token), restartGeneration == nil else { return false }
    restartGeneration = token
    return true
  }

  mutating func consumeRestart(for token: Int) -> Bool {
    guard isCurrent(token), restartGeneration == token else { return false }
    restartGeneration = nil
    return true
  }
}

/// Invalidates permission callbacks from a start request that was stopped
/// before the operating system finished asking for authorization.
struct SpeechStartGate {
  private var generation = 0

  mutating func begin() -> Int {
    generation += 1
    return generation
  }

  mutating func cancel() { generation += 1 }

  func isCurrent(_ token: Int) -> Bool { token == generation }
}

/// Native speech recognition for zh-TW. Streams partial transcripts on an
/// EventChannel and returns the final transcript from `stop`. A single audio
/// tap feeds the current request; each
/// finished utterance is committed and a new recognition session starts on the
/// same engine, so pausing mid-sentence accumulates instead of restarting.
class SpeechChannel: NSObject, FlutterStreamHandler, SFSpeechRecognitionTaskDelegate {
  static let eventChannelName = "reminder/speech_events"
  static let methodChannelName = "reminder/speech_cmd"

  private var eventSink: FlutterEventSink?
  private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))
  private var audioEngine: AVAudioEngine?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var activeToken: Int?
  private var running = false
  private var transcript = SpeechTranscriptAccumulator()
  private var startGate = SpeechStartGate()
  private var sessionGate = SpeechSessionGate()
  private var lastEmitted = ""

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = SpeechChannel()
    FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
      .setStreamHandler(channel)
    let cmd = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    cmd.setMethodCallHandler { call, result in
      switch call.method {
      case "start": channel.start(result: result)
      case "stop": channel.stop(result: result)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = eventSink
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.eventSink = nil
      self.startGate.cancel()
      self.tearDown()
    }
    return nil
  }

  private func emit(_ text: String) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(["text": text])
    }
  }

  // MARK: - Commands

  func start(result: @escaping FlutterResult) {
    let startToken = startGate.begin()
    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      DispatchQueue.main.async {
        guard let self else { return }
        guard self.startGate.isCurrent(startToken) else {
          result(FlutterError(code: "START_CANCELLED",
                              message: "Speech recognition start was cancelled.",
                              details: nil))
          return
        }
        guard status == .authorized else {
          result(FlutterError(code: "NO_PERMISSION",
                              message: "Speech recognition permission is required.",
                              details: nil))
          return
        }
        self.requestMic { granted in
          DispatchQueue.main.async {
            guard self.startGate.isCurrent(startToken) else {
              result(FlutterError(code: "START_CANCELLED",
                                  message: "Speech recognition start was cancelled.",
                                  details: nil))
              return
            }
            guard granted else {
              result(FlutterError(code: "NO_PERMISSION",
                                  message: "Microphone permission is required.",
                                  details: nil))
              return
            }
            do {
              try self.startEngine()
              result(nil)
            } catch {
              self.tearDown()
              result(FlutterError(code: "START_FAILED",
                                  message: error.localizedDescription,
                                  details: nil))
            }
          }
        }
      }
    }
  }

  func stop(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let final = self.transcript.fullText
      self.startGate.cancel()
      self.tearDown()
      result(final)
    }
  }

  private func requestMic(_ completion: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission(completionHandler: completion)
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission(completion)
    }
  }

  // MARK: - Engine

  private func startEngine() throws {
    guard let recognizer, recognizer.isAvailable else {
      throw NSError(domain: "SpeechChannel", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Recognizer unavailable"])
    }
    tearDown()

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .measurement, options: .duckOthers)
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let engine = AVAudioEngine()
    audioEngine = engine
    transcript = SpeechTranscriptAccumulator()
    lastEmitted = ""
    running = true

    // Single tap; always feeds the current request, so swapping requests on
    // restart keeps audio flowing without reinstalling the tap.
    let format = engine.inputNode.outputFormat(forBus: 0)
    engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
      self?.recognitionRequest?.append(buffer)
    }
    engine.prepare()
    try engine.start()

    guard startSession() else {
      throw NSError(domain: "SpeechChannel", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Could not start recognition"])
    }
  }

  @discardableResult
  private func startSession() -> Bool {
    guard running,
          let engine = audioEngine,
          engine.isRunning,
          let recognizer,
          recognizer.isAvailable
    else { return false }

    let token = sessionGate.beginSession()

    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionTask = nil
    activeToken = nil

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    // Allow Apple's online recognizer when an on-device model is unavailable.
    // Source: https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition
    request.requiresOnDeviceRecognition = false
    request.contextualStrings = [
      "今天", "明天", "後天", "早上", "中午", "下午", "晚上",
      "禮拜", "星期", "提醒", "記得", "吃藥", "醫生", "醫院",
    ]
    recognitionRequest = request
    activeToken = token
    recognitionTask = recognizer.recognitionTask(with: request, delegate: self)
    return recognitionTask != nil
  }

  // MARK: - SFSpeechRecognitionTaskDelegate

  func speechRecognitionTask(
    _ task: SFSpeechRecognitionTask,
    didHypothesizeTranscription transcription: SFTranscription
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.isActive(task) else { return }
      self.transcript.updatePartial(transcription.formattedString)
      self.emitIfChanged()
    }
  }

  func speechRecognitionTask(
    _ task: SFSpeechRecognitionTask,
    didFinishRecognition recognitionResult: SFSpeechRecognitionResult
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.isActive(task) else { return }
      self.transcript.updatePartial(recognitionResult.bestTranscription.formattedString)
      self.emitIfChanged(force: true)
      self.transcript.commitCurrent()
    }
  }

  func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully _: Bool) {
    DispatchQueue.main.async { [weak self] in self?.finishTask(task) }
  }

  func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
    DispatchQueue.main.async { [weak self] in self?.finishTask(task) }
  }

  // MARK: - Session lifecycle

  private func isActive(_ task: SFSpeechRecognitionTask) -> Bool {
    guard running, task === recognitionTask, let token = activeToken else { return false }
    return sessionGate.isCurrent(token)
  }

  private func finishTask(_ task: SFSpeechRecognitionTask) {
    guard isActive(task), let token = activeToken else { return }
    transcript.commitCurrent()
    emitIfChanged()
    scheduleRestart(for: token)
  }

  private func emitIfChanged(force: Bool = false) {
    let full = transcript.fullText
    guard force || full != lastEmitted else { return }
    lastEmitted = full
    emit(full)
  }

  private func scheduleRestart(for token: Int) {
    guard sessionGate.scheduleRestart(for: token) else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
      guard let self else { return }
      guard self.running, self.sessionGate.consumeRestart(for: token) else { return }
      if !self.startSession() { self.tearDown() }
    }
  }

  private func tearDown() {
    running = false
    sessionGate.invalidate()
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    audioEngine = nil
    recognitionRequest?.endAudio()
    recognitionRequest = nil
    recognitionTask?.cancel()
    recognitionTask = nil
    activeToken = nil
    transcript = SpeechTranscriptAccumulator()
    lastEmitted = ""
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
