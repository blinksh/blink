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

// VoiceDictation: one dictation at a time for the SmartKeys mic key
// (idle -> starting -> recording -> finishing -> idle), and VoiceStripView,
// the thin status strip shown above the keyboard while it runs.

import AVFoundation
import BlinkConfig
import UIKit

@MainActor
final class VoiceDictation {
  enum State: Equatable { case idle, starting, recording, finishing }

  struct Snapshot: Equatable {
    var state: State = .idle
    var level: Double = 0
    var elapsed: TimeInterval = 0
    var partial = ""
    /// A short note for the strip ("Microphone access is off", "Nothing heard").
    var note: String?
  }

  private(set) var snapshot = Snapshot() {
    didSet { if snapshot != oldValue { onUpdate?(snapshot) } }
  }
  var state: State { snapshot.state }

  /// Every change, on the main actor.
  var onUpdate: ((Snapshot) -> Void)?
  /// The finished text to type (nil = nothing heard), on the main actor.
  var onFinish: ((String?) -> Void)?

  private let mic: AudioCapturing
  private let makeTranscriber: () async -> SpeechTranscribing?
  private let speechAuthorize: () async -> Bool
  private let permissionPromptPending: () -> Bool
  /// The recognizer gets this long for its last words; then what was heard stands.
  private let finishTimeout: Duration
  /// Building + starting the recognizer, after the mic is open, under one cap.
  private let setupTimeout: Duration

  private var transcriber: SpeechTranscribing?
  private var box: TranscriberBox?
  private var startedAt: Date?
  private var ticker: Task<Void, Never>?
  private var stopRequested = false
  /// Bumped per recording: late callbacks from an earlier one are ignored.
  private var recordingID = 0

  init(mic: AudioCapturing, makeTranscriber: @escaping () async -> SpeechTranscribing?,
       speechAuthorize: @escaping () async -> Bool = { true },
       permissionPromptPending: @escaping () -> Bool = { false },
       finishTimeout: Duration = .seconds(4), setupTimeout: Duration = .seconds(8)) {
    self.mic = mic
    self.makeTranscriber = makeTranscriber
    self.speechAuthorize = speechAuthorize
    self.permissionPromptPending = permissionPromptPending
    self.finishTimeout = finishTimeout
    self.setupTimeout = setupTimeout
  }

  /// The real microphone and the on-device recognizer (built lazily, on first press).
  static func live() -> VoiceDictation {
    VoiceDictation(mic: MicCapture(), makeTranscriber: { await OnDeviceSpeech.make() },
                   speechAuthorize: { await OnDeviceSpeech.authorize() },
                   permissionPromptPending: {
                     MicCapture.permissionUndetermined || OnDeviceSpeech.permissionUndetermined
                   })
  }

  // MARK: Control

  func start() {
    guard state == .idle else { return }
    stopRequested = false
    snapshot = Snapshot(state: .starting)
    Task { await begin() }
  }

  func stop() {
    switch state {
    case .idle, .finishing: return
    case .starting: stopRequested = true        // begin() finishes or aborts
    case .recording: Task { await finish() }
    }
  }

  private func begin() async {
    // A press that raises a system permission alert is cancelled by it: nobody is holding
    // the key when the answers come back, so such a press records nothing.
    let prompted = permissionPromptPending()
    guard await mic.requestPermission() else {
      fail("Microphone access is off for Blink (Settings › Blink)."); return
    }
    guard await speechAuthorize() else {
      fail("Speech recognition is off for Blink (Settings › Blink)."); return
    }
    guard state == .starting else { return }
    if prompted { fail("Permissions set. Tap the mic again to dictate."); return }
    if stopRequested { idle(); return }

    recordingID += 1
    let myID = recordingID
    let box = TranscriberBox()
    self.box = box
    let format: AVAudioFormat
    do {
      format = try mic.start(
        onBuffer: { box.append($0) },
        onLevel: { [weak self] lvl in Self.onMain { self?.level(lvl, myID) } },
        onInterrupted: { [weak self] in Self.onMain { self?.interrupted(myID) } })
    } catch {
      mic.stop()
      fail("Couldn't start the microphone. Try again."); return
    }
    snapshot.state = .recording
    startedAt = Date()
    startTicker()

    // Build + start the recognizer as one bounded step. Words spoken meanwhile queue in
    // the box and are handed over in order.
    let make = makeTranscriber
    let raced: SpeechTranscribing?? = await race(setupTimeout) { [weak self] () -> SpeechTranscribing? in
      guard let s = await make() else { return nil }
      let started = await s.start(inputFormat: format, onPartial: { text in
        Self.onMain { self?.partial(text, myID) }
      })
      if !started { s.cancel() }
      return started ? s : nil
    }
    let speech: SpeechTranscribing? = raced ?? nil   // nil on timeout or no recognizer
    guard state == .recording, recordingID == myID else {
      speech?.cancel(); return                  // ended meanwhile
    }
    guard let speech else {
      mic.stop()
      box.detach()
      stopTicker()
      fail("On-device speech isn't available (no model for this language yet)."); return
    }
    transcriber = speech
    box.attach(speech)
    if stopRequested { await finish() }
  }

  private func finish() async {
    guard state == .recording, let startedAt else { return }
    snapshot.state = .finishing
    snapshot.level = 0
    stopTicker()
    mic.stop()
    let duration = Date().timeIntervalSince(startedAt)
    self.startedAt = nil
    let speech = transcriber
    transcriber = nil
    box?.detach()
    box = nil
    var text = snapshot.partial
    if let speech {
      // Bounded: a recognizer that never delivers is cancelled, and what was heard stands.
      if let final = await race(finishTimeout, { await speech.finish() }) {
        text = final
      } else {
        speech.cancel()
      }
    }
    let insert = VoiceInsert.text(from: text)
    if insert == nil {
      snapshot = Snapshot(note: RecordingRules.keep(duration: duration) ? "Nothing heard." : nil)
    } else {
      snapshot = Snapshot()
    }
    onFinish?(insert)
  }

  /// A hard stop that keeps nothing (the space is going away).
  func cancel() {
    recordingID += 1
    stopTicker()
    if state == .recording || state == .finishing { mic.stop() }
    transcriber?.cancel()
    transcriber = nil
    box?.detach()
    box = nil
    startedAt = nil
    snapshot = Snapshot()
  }

  // MARK: Internals

  private func fail(_ note: String) {
    stopTicker()
    startedAt = nil
    box = nil
    snapshot = Snapshot(note: note)
    onFinish?(nil)
  }

  private func idle() {
    snapshot = Snapshot()
    onFinish?(nil)
  }

  /// Clock + cap every 100 ms (a Task, so scrolling's run-loop mode can't pause it).
  private func startTicker() {
    ticker = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(100))
        self?.tick()
      }
    }
  }

  private func stopTicker() {
    ticker?.cancel()
    ticker = nil
  }

  private func tick() {
    guard state == .recording, let startedAt else { return }
    snapshot.elapsed = Date().timeIntervalSince(startedAt)
    if RecordingRules.shouldStop(elapsed: snapshot.elapsed) {
      Task { await finish() }
    }
  }

  private func level(_ lvl: Double, _ id: Int) {
    guard id == recordingID, state == .recording else { return }
    snapshot.level = lvl
  }

  private func partial(_ text: String, _ id: Int) {
    guard id == recordingID, state == .recording || state == .finishing else { return }
    snapshot.partial = text
  }

  private func interrupted(_ id: Int) {
    guard id == recordingID, state == .recording else { return }
    Task { await finish() }
  }

  /// `op`, or nil once `limit` passes, whichever is first. The loser keeps running
  /// unstructured; callers cancel what they own.
  private func race<T>(_ limit: Duration, _ op: @escaping @MainActor () async -> T) async -> T? {
    await withCheckedContinuation { (cont: CheckedContinuation<T?, Never>) in
      let once = ResumeOnce(cont)
      let timer = Task { @MainActor in
        try? await Task.sleep(for: limit)
        if !Task.isCancelled { once.resume(nil) }
      }
      Task { @MainActor in
        let value = await op()
        timer.cancel()
        once.resume(value)
      }
    }
  }

  nonisolated private static func onMain(_ work: @escaping @MainActor () -> Void) {
    if #available(iOS 17, *), Thread.isMainThread {
      MainActor.assumeIsolated { work() }
    } else {
      DispatchQueue.main.async { work() }
    }
  }
}

/// A continuation resumed at most once (main actor only).
@MainActor
private final class ResumeOnce<T> {
  private var cont: CheckedContinuation<T?, Never>?
  init(_ cont: CheckedContinuation<T?, Never>) { self.cont = cont }
  func resume(_ value: T?) {
    guard let c = cont else { return }
    cont = nil
    c.resume(returning: value)
  }
}

// MARK: - The strip above the keyboard

/// Red dot, "Listening 0:03", a level bar and the live transcript. Shown while a dictation
/// runs; a note lingers for a moment after it ends. Never takes touches.
final class VoiceStripView: UIView {
  private let dot = UIView()
  private let status = UILabel()
  private let transcript = UILabel()
  private let meter = UIView()
  private var meterWidth: NSLayoutConstraint!
  private var hideTask: Task<Void, Never>?

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    translatesAutoresizingMaskIntoConstraints = false
    alpha = 0

    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    blur.translatesAutoresizingMaskIntoConstraints = false
    blur.layer.cornerRadius = 12
    blur.clipsToBounds = true
    addSubview(blur)

    dot.translatesAutoresizingMaskIntoConstraints = false
    dot.backgroundColor = .systemRed
    dot.layer.cornerRadius = 5

    status.translatesAutoresizingMaskIntoConstraints = false
    status.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
    status.textColor = .label

    transcript.translatesAutoresizingMaskIntoConstraints = false
    transcript.font = .systemFont(ofSize: 14)
    transcript.textColor = .label
    transcript.numberOfLines = 2
    transcript.lineBreakMode = .byTruncatingHead   // the newest words stay visible

    meter.translatesAutoresizingMaskIntoConstraints = false
    meter.backgroundColor = UIColor.systemRed.withAlphaComponent(0.6)
    meter.layer.cornerRadius = 1.5

    let content = blur.contentView
    [dot, status, transcript, meter].forEach(content.addSubview)
    meterWidth = meter.widthAnchor.constraint(equalToConstant: 0)

    NSLayoutConstraint.activate([
      blur.topAnchor.constraint(equalTo: topAnchor),
      blur.bottomAnchor.constraint(equalTo: bottomAnchor),
      blur.leadingAnchor.constraint(equalTo: leadingAnchor),
      blur.trailingAnchor.constraint(equalTo: trailingAnchor),

      dot.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
      dot.centerYAnchor.constraint(equalTo: status.centerYAnchor),
      dot.widthAnchor.constraint(equalToConstant: 10),
      dot.heightAnchor.constraint(equalToConstant: 10),

      status.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
      status.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
      status.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),

      meter.leadingAnchor.constraint(equalTo: status.trailingAnchor, constant: 10),
      meter.centerYAnchor.constraint(equalTo: status.centerYAnchor),
      meter.heightAnchor.constraint(equalToConstant: 3),
      meterWidth,

      transcript.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 4),
      transcript.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
      transcript.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
      transcript.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
    ])
  }

  required init?(coder: NSCoder) { nil }

  func render(_ s: VoiceDictation.Snapshot) {
    hideTask?.cancel()
    hideTask = nil
    switch s.state {
    case .starting:
      show()
      dot.isHidden = false
      dot.alpha = 0.4
      status.text = "Starting…"
      transcript.text = "Hold or tap the mic again to stop."
      meterWidth.constant = 0
    case .recording:
      show()
      dot.isHidden = false
      dot.alpha = 1
      status.text = "Listening \(RecordingRules.clock(s.elapsed))"
      transcript.text = s.partial.isEmpty ? "Speak; the words are typed when you stop." : s.partial
      meterWidth.constant = CGFloat(s.level) * 80
    case .finishing:
      dot.alpha = 0.4
      status.text = "Finishing…"
      transcript.text = s.partial.isEmpty ? "…" : s.partial
      meterWidth.constant = 0
    case .idle:
      if let note = s.note {
        show()
        dot.isHidden = true
        status.text = "Dictation"
        transcript.text = note
        meterWidth.constant = 0
        hideTask = Task { [weak self] in
          try? await Task.sleep(for: .seconds(3))
          if !Task.isCancelled { self?.hide() }
        }
      } else {
        hide()
      }
    }
  }

  private func show() {
    guard alpha < 1 else { return }
    UIView.animate(withDuration: 0.15) { self.alpha = 1 }
  }

  private func hide() {
    guard alpha > 0 else { return }
    UIView.animate(withDuration: 0.2) { self.alpha = 0 }
  }
}
