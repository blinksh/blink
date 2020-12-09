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
  var tunnel: [SSHPortForwardListener] = []
  var reverseTunnels: [SSHPortForwardClient] = []
  var tunnelStream: SSH.Stream?
  var reverseTunnelStream: SSH.Stream?
  var proxyThread: Thread?
  
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
    
    SSH.SSHClient.dial(cmd.host, with: config, withProxy: executeProxyCommand)
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
        self.startInteractiveSessions(conn, command: cmd)
        self.startForwardTunnels(conn, command: cmd)
        self.startReverseTunnels(conn, command: cmd)
      }).store(in: &cancellableBag)

    CFRunLoopRun()

    device.rawMode = originalRawMode
    return exitCode
  }
  
  func executeProxyCommand(command: String, sockIn: Int32, sockOut: Int32) {
    // If this is a jump, we process it here.
    // Otherwise we execute another command through the shell.
    
    // TODO Possible issues with the command, as components may not be enough.
    
    // TODO Thread per connection should be handled by the pool,
    // but for now we will dump it here.
    proxyThread = Thread {
      let args = command.dropFirst("ssh ".count)
      guard let cmd = try? SSHCommand.parse(args.components(separatedBy: " ")) else {
        print("Unrecognized command")
        return
      }

      var connection: SSH.SSHClient?
      var proxyStream: SSH.Stream?
      
      let config = SSHClientConfigProvider.config(command: cmd, using: self.device)
      
//      let c = SSHClient.dial(cmd.host, with: config)
//        .flatMap { conn -> AnyPublisher<SSH.Stream, Error> in
//          connection = conn
//          // TODO There is a mismatch on Port, config gets a string, but we
//          // use Int32 everywhere else.
//          return conn.requestForward(to: cmd.host, port: cmd.portNum,
//                                     // TODO Just informative, should make optional.
//                                     from: "localhost", localPort: 22)
//        }.sink(receiveCompletion: { end in
//          switch end {
//          case .failure(let error):
//            close(sockIn)
//            close(sockOut)
//            print("Proxy Command failed to execute \(error)")
//          default:
//            break
//          }
//        }, receiveValue: { s in
//          let output = DispatchOutputStream(stream: sockOut)
//          let input = DispatchInputStream(stream: sockIn)
//          proxyStream = s
//          s.connect(stdout: output, stdin: input)
//        })
      
      CFRunLoopRun()
    }
    
    proxyThread?.start()
  }
  
  func startInteractiveSessions(_ conn: SSH.SSHClient, command: SSHCommand) {
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
  
  func startForwardTunnels(_ conn: SSH.SSHClient, command: SSHCommand) {
//    if let tunnel = command.localPortForward {
//      let lis: SSHPortForwardListener
//      do {
//        lis = try SSHPortForwardListener(on: tunnel.localPort, toDestination: tunnel.bindAddress, on: tunnel.remotePort, using: conn)
//      } catch {
//        print("Listener configuration error \(error)")
//        self.kill()
//        return
//      }
//      tunnel.append(lis)
//
//      // TODO: Will update the interface so you do not have to keep a
//      // reference to the stream sent from the tunnel
//      lis.receive().sink(receiveCompletion: { completion in
//        switch completion {
//        case .finished:
//          print("Tunnel finished")
//        case .failure(let error):
//          print("TUNNEL ERROR \(error)")
//        }
//      }, receiveValue: { event in
//        switch event {
//        case .received(let streamPub):
//          streamPub.assertNoFailure().sink { self.tunnelStream = $0 }.store(in: &self.cancellableBag)
//        default:
//          print("Tunnel received \(event)")
//        } }).store(in: &cancellableBag)
//    }
  }
  
  func startReverseTunnels(_ conn: SSH.SSHClient, command: SSHCommand) {
//    if let localPort = command.reversePortForwardLocalPort,
//       let tunnelHost = command.reversePortForwardHost,
//       let remotePort = command.reversePortForwardRemotePort {
//      let client: SSHPortForwardClient
//      do {
//        client = try SSHPortForwardClient(forward: tunnelHost,
//                                          onPort: localPort,
//                                          toRemotePort: remotePort,
//                                          using: conn)
//      } catch {
//        print("Client configuration error \(error)")
//        self.kill()
//        return
//      }
//      reverseTunnels.append(client)
//
//      // TODO Same issue here, we should get the stream on the fwd side.
//      client.connect().sink(receiveCompletion: { completion in
//        switch completion {
//        case .finished:
//          print("Reverse tunnel finished")
//        case .failure(let error):
//          print("Reverse tunnel error \(error)")
//        }
//      }, receiveValue: { event in
//        switch event {
//        case .received(let streamPub):
//          streamPub.assertNoFailure().sink { self.reverseTunnelStream = $0 }
//            .store(in: &self.cancellableBag)
//        default:
//          print("Reverse tunnel event \(event)")
//        }
//      }).store(in: &self.cancellableBag)
//    }
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
