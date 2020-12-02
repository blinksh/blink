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
import SSH
import Combine
import Dispatch


@objc public class BlinkSSH: NSObject {
  let stdout: Int32
  let stdin: Int32
  let device: TermDevice
  
  var exitCode = 0
  var cancellableBag: Set<AnyCancellable> = []
  var connection: SSH.SSHClient?
  var currentRunLoop: RunLoop?
  var connectionSetup: AnyCancellable?
  var stream: SSH.Stream?

  @objc public init(stdout: Int32, andStdin stdin: Int32, device dev: TermDevice) {
    // Duplicate before transforming them, because ios_sytem
    // still needs the original streams.
    self.stdout = stdout
    self.stdin = stdin
    self.device = dev
  }
  
  @objc public func start(_ argc: Int, argv: [String]) -> Int {
    let originalRawMode = device.rawMode
    
    currentRunLoop = RunLoop.current
    
    let cmd: SSHCommand
    do {
      cmd = try SSHCommand.parse(Array(argv[1...]))
    } catch {
      let message = SSHCommand.message(for: error)
      print("\(message)")
      return -1
    }
    
    let config = SSHClientConfigProvider.config(command: cmd, using: device)
    
    SSH.SSHClient.dial(cmd.host, with: config)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          print(error)
          self.kill()
        default:
          // Connection OK
          break
        }
      }, receiveValue: { conn in
        self.connection = conn
        self.startSessions(conn, command: cmd)
      }).store(in: &cancellableBag)

    CFRunLoopRun()

    device.rawMode = originalRawMode
    return exitCode
  }
  
  func startSessions(_ conn: SSH.SSHClient, command: SSHCommand) {
    let rows = self.device.rows
    let cols = self.device.cols

    conn.requestInteractiveShell(rows: Int32(rows), columns: Int32(cols))
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          print(error)
          self.kill()
          return
        default:
          // Interactive OK
          break
        }
      }, receiveValue: { s in
        self.stream = s
        self.device.rawMode = true
        s.handleCompletion = {
          // Once finished, exit.
          self.kill()
          return
        }
        s.handleFailure = { error in
          self.exitCode = -1
          print("ERROR \(error)")
          self.kill()
          return
        }
        let outStream = DispatchOutputStream(stream: dup(self.stdout))
        let inStream = DispatchInputStream(stream: dup(self.stdin))

        s.connect(stdout: outStream, stdin: inStream)
      }).store(in: &cancellableBag)
  }
  
  @objc public func sigwinch() {
    var c: AnyCancellable?
    c = stream?.resizePty(rows: Int32(device.rows), columns: Int32(device.cols))
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          print(error)
        default:
          c = nil
        }
      }, receiveValue: {})
  }
  
  @objc public func kill() {
    cancellableBag.forEach { $0.cancel() }
    stream?.cancel()
    
    if let cfRunLoop = currentRunLoop?.getCFRunLoop() {
      CFRunLoopStop(cfRunLoop)
    }
  }
}
