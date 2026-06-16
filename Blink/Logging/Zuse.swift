//////////////////////////////////////////////////////////////////////////////////
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


import Combine
import Foundation

// Application-wide logger. Component loggers share handlers built once from config,
// fanning out to stdout and an optional file.
final class Zuse {
  static let shared = Zuse()

  // The catalog of logging surfaces. Add a case per surface; the raw value is the
  // label that appears in output and in Settings.
  enum Component: String, CaseIterable {
    case app      = "App"
    case terminal = "Terminal"
    case input    = "Input"
    case config   = "Config"
  }

  struct LogConfig {
    var minLevel: BlinkLogLevel
    var components: Set<Component>?   // nil = all components
    var fileURL: URL?                 // nil = stdout only

    static let `default` = LogConfig(minLevel: .info, components: nil, fileURL: nil)

    var allowedNames: Set<String>? { components.map { Set($0.map(\.rawValue)) } }
  }

  static let maxLogBytes: UInt64 = 5 * 1024 * 1024

  private let handlers: [BlinkLogging.LogHandlerFactory]
  // Retained to keep the file handle open.
  private let sessionFile: SessionLogFile?

  private init(config: LogConfig = .default) {
    var handlers = [BlinkLogging.LogHandlerFactory]()
    var sessionFile: SessionLogFile?

    if let url = config.fileURL {
      do {
        let file = try SessionLogFile(to: url, maxBytes: Self.maxLogBytes)
        sessionFile = file
        handlers.append(Self.fileHandler(config, file: file))
      } catch {
        Swift.print("Zuse: failed to open log file \(url.path) - \(error)")
      }
    }
    handlers.append(Self.outputHandler(config))

    self.handlers = handlers
    self.sessionFile = sessionFile
  }

  // MARK: - Public API

  func logger(_ component: Component, _ subcomponent: String? = nil) -> BlinkLogger {
    var label: [BlinkLogKeys: Any] = [.component: component.rawValue]
    if let subcomponent = subcomponent {
      label[.subcomponent] = subcomponent
    }
    return BlinkLogger(bootstrap: { publisher in
      publisher
        .map { $0.merging(label, uniquingKeysWith: { _, new in new }) }
        .eraseToAnyPublisher()
    }, handlers: handlers)
  }

  static func logger(_ component: Component, _ subcomponent: String? = nil) -> BlinkLogger {
    shared.logger(component, subcomponent)
  }

  // Logs a final message and drains the file so nothing in flight is lost.
  func shutdown(_ message: String = "Goodbye, Blink") {
    logger(.app).info(message)
    sessionFile?.flush()
  }

  // MARK: - Internals

  private static func outputHandler(_ config: LogConfig) -> BlinkLogging.LogHandlerFactory {
    { publisher in
      publisher
        .filter(logLevel: config.minLevel)
        .filter(components: config.allowedNames)
        .format(standardFormat)
        .sinkToOutput()
    }
  }

  private static func fileHandler(_ config: LogConfig, file: SessionLogFile) -> BlinkLogging.LogHandlerFactory {
    { publisher in
      publisher
        .filter(logLevel: config.minLevel)
        .filter(components: config.allowedNames)
        .format(standardFormat)
        .sinkToSessionFile(file)
    }
  }

  static func standardFormat(_ record: [BlinkLogKeys: Any]) -> String {
    var label = record[.component] as? String ?? "global"
    if let subcomponent = record[.subcomponent] as? String {
      label += "/\(subcomponent)"
    }
    return [
      "[\(Date().formatted(.iso8601))]",
      "[\(record[.logLevel] ?? BlinkLogLevel.log)]",
      label,
      record[.message] as? String ?? ""
    ].joined(separator: " : ")
  }
}

extension BlinkLogKeys {
  static let subcomponent = BlinkLogKeys("subcomponent")
}

// ObjC bridge. Swift uses `Zuse.logger(...)` directly; this exposes a minimal
// surface to .m files via Blink-Swift.h. Add a factory per component as needed.
@objc(ZuseLog)
final class ZuseLog: NSObject {
  private let log: BlinkLogger

  private init(_ component: Zuse.Component) {
    self.log = Zuse.logger(component)
  }

  @objc static func app() -> ZuseLog { ZuseLog(.app) }

  @objc static func shutdown() { Zuse.shared.shutdown() }

  @objc func debug(_ message: String) { log.debug(message) }
  @objc func info(_ message: String)  { log.info(message) }
  @objc func warn(_ message: String)  { log.warn(message) }
  @objc func error(_ message: String) { log.error(message) }
}

extension Publisher where Output == [BlinkLogKeys: Any], Failure == Never {
  // Keeps only the listed components; passes everything when nil.
  func filter(components: Set<String>?) -> AnyPublisher<[BlinkLogKeys: Any], Never> {
    guard let components = components else { return eraseToAnyPublisher() }
    return filter { components.contains($0[.component] as? String ?? "global") }
      .eraseToAnyPublisher()
  }

  func sinkToSessionFile(_ file: SessionLogFile) -> AnyCancellable {
    receive(on: file.queue)
      .sink(receiveCompletion: { _ in },
            receiveValue: { record in
              let line = "\(record[.message] as? String ?? "")\n"
              if let data = line.data(using: .utf8) {
                file.write(data)
              }
            })
  }
}
