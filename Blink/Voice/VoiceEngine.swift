////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

// On-device dictation engine for the SmartKeys mic key: one AVAudioEngine input
// tap feeds an on-device recognizer (SpeechAnalyzer on iOS 26, SFSpeechRecognizer
// before that). Nothing is written to disk and nothing leaves the phone.

import AVFoundation
import BlinkConfig
import Foundation
import Speech

// MARK: - Seams

/// The microphone: one input tap, buffers out, plus a level for the meter.
protocol AudioCapturing: AnyObject {
  func requestPermission() async -> Bool
  /// Starts capture; returns the tap's buffer format. `onBuffer` and `onLevel` run on the
  /// audio thread; `onInterrupted` (a call, Siri, a route/config change) on any thread.
  func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void,
             onLevel: @escaping (Double) -> Void,
             onInterrupted: @escaping () -> Void) throws -> AVAudioFormat
  func stop()
}

/// On-device speech recognition for one recording.
protocol SpeechTranscribing: AnyObject {
  /// False when it can't run. `onPartial` gets the whole transcript so far, from any thread.
  func start(inputFormat: AVAudioFormat, onPartial: @escaping (String) -> Void) async -> Bool
  /// Called on the audio thread.
  func append(_ buffer: AVAudioPCMBuffer)
  /// End of audio: the final transcript (unbounded here; the caller races it).
  func finish() async -> String
  func cancel()
}

// MARK: - Microphone

final class MicCapture: AudioCapturing {
  private var engine: AVAudioEngine?
  private var observers: [NSObjectProtocol] = []

  func requestPermission() async -> Bool {
    if #available(iOS 17, *) {
      return await AVAudioApplication.requestRecordPermission()
    }
    return await withCheckedContinuation { cont in
      AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
    }
  }

  static var permissionUndetermined: Bool {
    if #available(iOS 17, *) {
      return AVAudioApplication.shared.recordPermission == .undetermined
    }
    return AVAudioSession.sharedInstance().recordPermission == .undetermined
  }

  func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void,
             onLevel: @escaping (Double) -> Void,
             onInterrupted: @escaping () -> Void) throws -> AVAudioFormat {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .measurement)
    try session.setActive(true, options: .notifyOthersOnDeactivation)
    let engine = AVAudioEngine()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      throw NSError(domain: "blink.voice", code: 1)
    }
    input.installTap(onBus: 0, bufferSize: 4096, format: format) { buf, _ in
      onBuffer(buf)
      onLevel(RecordingRules.level(fromPower: Self.power(buf)))
    }
    engine.prepare()
    do {
      try engine.start()
    } catch {
      input.removeTap(onBus: 0)
      throw error
    }
    self.engine = engine
    // A call / Siri / alarm (interruption began) or a route or format change (the
    // engine stops itself on a config change): the recording stops like a release.
    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: AVAudioSession.interruptionNotification, object: session,
                         queue: nil) { note in
        let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        if raw.flatMap(AVAudioSession.InterruptionType.init) == .began { onInterrupted() }
      },
      center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine,
                         queue: nil) { [weak engine] _ in
        if engine?.isRunning != true { onInterrupted() }
      }
    ]
    return format
  }

  func stop() {
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
    if let engine {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    engine = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  /// RMS of channel 0 in dBFS.
  private static func power(_ buf: AVAudioPCMBuffer) -> Float {
    guard let ch = buf.floatChannelData?[0], buf.frameLength > 0 else { return -160 }
    var sum: Float = 0
    for i in 0..<Int(buf.frameLength) { sum += ch[i] * ch[i] }
    let rms = (sum / Float(buf.frameLength)).squareRoot()
    return rms > 0 ? 20 * log10(rms) : -160
  }
}

// MARK: - Recognizer choice

enum OnDeviceSpeech {
  /// The on-device recognizer to use, or nil (Speech denied / no on-device model).
  /// Never prompts: `authorize()` has already run.
  static func make() async -> SpeechTranscribing? {
    let authorized = SFSpeechRecognizer.authorizationStatus() == .authorized
    var analyzerReady = false
    if authorized, #available(iOS 26, *) {
      analyzerReady = await AnalyzerSpeech.ready()
    }
    let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer()
    let onDevice = recognizer.map { $0.isAvailable && $0.supportsOnDeviceRecognition } ?? false
    switch VoicePath.choose(speechAuthorized: authorized, analyzerReady: analyzerReady,
                            recognizerOnDevice: onDevice) {
    case .analyzer:
      if #available(iOS 26, *) { return AnalyzerSpeech() }
      return nil
    case .recognizer:
      return recognizer.map { RecognizerSpeech(recognizer: $0) }
    case .none:
      return nil
    }
  }

  /// Asks for Speech permission if undecided (shows the system prompt); true when granted.
  static func authorize() async -> Bool {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized: return true
    case .notDetermined:
      return await withCheckedContinuation { cont in
        SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
      }
    default: return false
    }
  }

  static var permissionUndetermined: Bool {
    SFSpeechRecognizer.authorizationStatus() == .notDetermined
  }
}

// MARK: - SFSpeechRecognizer (iOS 16–18, and 26 without the new model installed)

final class RecognizerSpeech: SpeechTranscribing, @unchecked Sendable {
  private let recognizer: SFSpeechRecognizer
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private let lock = NSLock()
  private var latest = ""
  private var done = false
  private var waiter: CheckedContinuation<Void, Never>?

  init(recognizer: SFSpeechRecognizer) { self.recognizer = recognizer }

  func start(inputFormat: AVAudioFormat, onPartial: @escaping (String) -> Void) async -> Bool {
    guard recognizer.supportsOnDeviceRecognition else { return false }
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = true
    request.addsPunctuation = true
    lock.withLock { self.request = request }
    let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self else { return }
      if let result {
        let text = result.bestTranscription.formattedString
        self.lock.withLock { self.latest = text }
        onPartial(text)
        if result.isFinal { self.markDone() }
      }
      if error != nil { self.markDone() }
    }
    lock.withLock { self.task = task }
    return true
  }

  func append(_ buffer: AVAudioPCMBuffer) { lock.withLock { request }?.append(buffer) }

  private func endAudio() {
    let req = lock.withLock { () -> SFSpeechAudioBufferRecognitionRequest? in
      defer { request = nil }
      return request
    }
    req?.endAudio()
  }

  func finish() async -> String {
    endAudio()
    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
      let ready = self.lock.withLock {
        if self.done { return true }
        self.waiter = c
        return false
      }
      if ready { c.resume() }
    }
    lock.withLock { task }?.finish()
    return lock.withLock { latest }
  }

  func cancel() {
    lock.withLock { task }?.cancel()
    endAudio()
    markDone()
  }

  private func markDone() {
    lock.lock()
    done = true
    let w = waiter
    waiter = nil
    lock.unlock()
    w?.resume()
  }
}

// MARK: - SpeechAnalyzer (iOS 26)

@available(iOS 26, *)
final class AnalyzerSpeech: SpeechTranscribing, @unchecked Sendable {
  private var analyzer: SpeechAnalyzer?
  private var results: Task<Void, Never>?
  private struct Feed {
    let input: AsyncStream<AnalyzerInput>.Continuation
    let target: AVAudioFormat
    let converter: AVAudioConverter?
  }
  private var feed: Feed?
  private let lock = NSLock()
  private var acc = TranscriptAccumulator()

  /// The model for this locale is installed. If it's only downloadable, start the download
  /// for next time and say no (this recording uses the older recognizer).
  static func ready() async -> Bool {
    guard SpeechTranscriber.isAvailable,
          let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) else { return false }
    let module = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
    switch await AssetInventory.status(forModules: [module]) {
    case .installed:
      return true
    case .supported:
      Task.detached(priority: .background) {
        try? await AssetInventory.assetInstallationRequest(supporting: [module])?.downloadAndInstall()
      }
      return false
    default:
      return false
    }
  }

  func start(inputFormat: AVAudioFormat, onPartial: @escaping (String) -> Void) async -> Bool {
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) else { return false }
    let module = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
    guard let target = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module],
                                                                      considering: inputFormat)
    else { return false }
    var converter: AVAudioConverter?
    if target != inputFormat {
      guard let c = AVAudioConverter(from: inputFormat, to: target) else { return false }
      converter = c
    }
    let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    let analyzer = SpeechAnalyzer(modules: [module])
    do {
      try await analyzer.prepareToAnalyze(in: target)
      try await analyzer.start(inputSequence: stream)
    } catch {
      continuation.finish()
      return false
    }
    let results = Task { [weak self] in
      do {
        for try await r in module.results {
          guard let self else { return }
          let text = self.lock.withLock {
            self.acc.add(String(r.text.characters), isFinal: r.isFinal)
            return self.acc.text
          }
          onPartial(text)
        }
      } catch {}
    }
    lock.withLock {
      self.analyzer = analyzer
      self.results = results
      feed = Feed(input: continuation, target: target, converter: converter)
    }
    return true
  }

  func append(_ buffer: AVAudioPCMBuffer) {
    guard let feed = lock.withLock({ feed }) else { return }
    let input = feed.input
    let target = feed.target
    guard let converter = feed.converter else {
      // the stream outlives the tap callback: hand it a copy, not the engine's buffer
      if let copy = copyPCM(buffer) { input.yield(AnalyzerInput(buffer: copy)) }
      return
    }
    let ratio = target.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
    guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
    var fed = false
    var err: NSError?
    converter.convert(to: out, error: &err) { _, status in
      if fed { status.pointee = .noDataNow; return nil }
      fed = true
      status.pointee = .haveData
      return buffer
    }
    if err == nil, out.frameLength > 0 { input.yield(AnalyzerInput(buffer: out)) }
  }

  private func endInput() {
    let feed = lock.withLock { () -> Feed? in
      defer { self.feed = nil }
      return self.feed
    }
    feed?.input.finish()
  }

  func finish() async -> String {
    endInput()
    let (analyzer, results) = lock.withLock { (self.analyzer, self.results) }
    try? await analyzer?.finalizeAndFinishThroughEndOfInput()
    await results?.value
    return lock.withLock { acc.text }
  }

  func cancel() {
    endInput()
    let (analyzer, results) = lock.withLock { (self.analyzer, self.results) }
    results?.cancel()
    Task { await analyzer?.cancelAndFinishNow() }
  }
}

// MARK: - Buffer plumbing

/// Feeds the recognizer from the audio thread. Until it's attached, buffers queue (bounded,
/// ~30 s) so the first words aren't lost while the model spins up.
final class TranscriberBox: @unchecked Sendable {
  private let lock = NSLock()
  private var target: SpeechTranscribing?
  private var pending: [AVAudioPCMBuffer] = []
  private var closed = false
  private var pendingFrames: AVAudioFramePosition = 0

  func append(_ buf: AVAudioPCMBuffer) {
    lock.lock()
    defer { lock.unlock() }
    if let target { target.append(buf); return }
    guard !closed, Double(pendingFrames) < 30 * buf.format.sampleRate,
          let copy = copyPCM(buf) else { return }
    pending.append(copy)                 // the engine may reuse a tap buffer
    pendingFrames += AVAudioFramePosition(buf.frameLength)
  }

  func attach(_ speech: SpeechTranscribing) {
    lock.lock()
    defer { lock.unlock() }
    pending.forEach(speech.append)
    pending = []
    target = speech
  }

  func detach() {
    lock.lock()
    defer { lock.unlock() }
    closed = true
    pending = []
    target = nil
  }
}

/// A private copy of a tap buffer (the engine may reuse its buffers after the callback).
func copyPCM(_ buf: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
  guard let out = AVAudioPCMBuffer(pcmFormat: buf.format, frameCapacity: buf.frameLength) else {
    return nil
  }
  out.frameLength = buf.frameLength
  let src = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buf.audioBufferList))
  let dst = UnsafeMutableAudioBufferListPointer(out.mutableAudioBufferList)
  for (from, to) in zip(src, dst) {
    guard let fromData = from.mData, let toData = to.mData else { return nil }
    memcpy(toData, fromData, Int(min(from.mDataByteSize, to.mDataByteSize)))
  }
  return out
}
