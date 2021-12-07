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


import Foundation
import Combine

public class FileLogging {
  private let h: FileHandle
  let queue = DispatchQueue(label: "FileLogging")
  
  public init(to url: URL) throws {
    let fm = FileManager.default
    
    let attrs: [FileAttributeKey : Any] = [.protectionKey: FileProtectionType.none]
    
    if !fm.fileExists(atPath: url.path) {
      guard fm.createFile(atPath: url.path, contents: nil, attributes: attrs) else {
        throw NSError(domain: NSPOSIXErrorDomain, code: 1)
      }
    } else {
      try fm.setAttributes(attrs, ofItemAtPath: url.path)
    }
    
    self.h = try FileHandle(forWritingTo: url)
    h.truncateFile(atOffset: 0)
    //h.seekToEndOfFile()
  }
  
  func write(_ data: Data) {
    do {
      try h.write(contentsOf: data)
    } catch {
      debugPrint("Failed to write log: ", error)
    }
  }
}

extension Publisher {
  public func sinkToFile(_ file: FileLogging) throws -> AnyCancellable where Self.Output == [BlinkLogKeys:Any] {
    // TODO receive(on:)
    return receive(on: file.queue)
      .sink(receiveCompletion: { _ in},
                receiveValue: { string in
      let string = "\(string[.message] as? String ?? "")\n"
      if let data = (string).data(using: .utf8) {
        file.write(data)
      }
    })
  }

  public func sinkToOutput() -> AnyCancellable where Self.Output == [BlinkLogKeys:Any] {
    return sink(receiveCompletion: { _ in },
                receiveValue: { Swift.print($0[.message] ?? "") })
  }

  public func filter(logLevel: BlinkLogLevel) -> AnyPublisher<[BlinkLogKeys:Any], Never>
  where Self.Output == [BlinkLogKeys:Any], Self.Failure == Never {
      return filter { log in
        guard let filterLogLevel = log[.logLevel] as? BlinkLogLevel else {
          return false
        }
        return filterLogLevel >= logLevel }
        .eraseToAnyPublisher()
  }

  public func format(_ formatter: @escaping ([BlinkLogKeys:Any]) -> String) -> AnyPublisher<[BlinkLogKeys:Any], Never>
  where Self.Output == [BlinkLogKeys:Any], Self.Failure == Never {
    return map {
      $0.merging([.message: formatter($0)],
                 uniquingKeysWith: { (_, new) in new })
    }.eraseToAnyPublisher()
  }
}
