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
import Network

import LibSSH

struct SOCKSError: Error {
  
}

enum SOCKSAddressType: UInt8 {
  case ipv4 = 1
  case domain = 3
  case ipv6 = 4
}

enum SOCKSRequestType: UInt8 {
  case connect = 1
  case bind = 2
  case udp = 3
}

enum SOCKSReplyType: UInt8 {
  case succeeded = 0
  case failure = 1
  case notAllowed = 2
  case unreachable = 3
}

struct SOCKSMessageHeader { // :Codable
  let version = 5
  let request: SOCKSRequestType?
  let reply: SOCKSReplyType?
  let addressType: SOCKSAddressType
  let domainLength: UInt8?
  
  static var baseEncodedSize:   Int { MemoryLayout<UInt8>.size * 4 }
  static var domainEncodedSize: Int { Self.baseEncodedSize + MemoryLayout<UInt8>.size }
  var encodedSize: Int { addressType == .domain ? Self.domainEncodedSize : Self.baseEncodedSize }

  var messageLength: Int {
    let portLength = SOCKSMessage.portLength
    
    switch addressType {
    case .ipv4:
      return MemoryLayout<CChar>.size * 4 + portLength
    case .domain:
      return Int(domainLength!) + portLength
    case .ipv6:
      return MemoryLayout<CChar>.size * 16 + portLength
    }
  }

  init?(_ buffer: UnsafeMutableRawBufferPointer) {
    guard let request = SOCKSRequestType(rawValue: buffer.load(fromByteOffset: 1, as: UInt8.self)) else {
      return nil
    }
    self.request = request
    self.reply = nil
    guard let addressType = SOCKSAddressType(rawValue: buffer.load(fromByteOffset: 3, as: UInt8.self)) else {
      return nil
    }
    self.addressType = addressType
    if self.addressType == .domain {
      if buffer.count < Self.domainEncodedSize {
        return nil
      }
      self.domainLength = buffer.load(fromByteOffset: 4, as: UInt8.self)
    } else {
      self.domainLength = nil
    }
  }
  
  init(reply: SOCKSReplyType, addressType: SOCKSAddressType, domainLength: UInt8? = nil) {
    self.reply = reply
    self.request = nil
    self.addressType = addressType
    self.domainLength = domainLength
  }
  
  var encodedData: Data {
    guard var reply = self.reply else {
      return Data()
    }
    var type = addressType.rawValue
    var bytes = Data([0x05]) // ver
      + Data(bytes: &reply, count: MemoryLayout<UInt8>.size) // cmd
      + Data([0x00]) // rsrv
      + Data(bytes: &type, count: MemoryLayout<UInt8>.size) // type
    
    
    if var domainLength = self.domainLength {
      bytes += Data(bytes: &domainLength, count: MemoryLayout<UInt8>.size) // Length for domain string
    }
    
    return bytes
  }
}

// Serve the PAC from blink.sh
struct SOCKSMessage {
  static let portLength = MemoryLayout<UInt8>.size * 2
  
  let data: Data
  let address: String
  let port: UInt16

  init?(_ data: Data, type: SOCKSAddressType) {
    let addressLength: UInt32 = UInt32(data.count - Self.portLength)
    var addressData = data[0..<addressLength]
    let portData = data[addressLength...]
    
    var address: [CChar] = Array(repeating: 0, count: Int(addressLength))
    switch(type) {
    case .ipv4:
      self.address = addressData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<CChar>) in
        inet_ntop(AF_INET, bytes, &address, addressLength)
        return String(cString: address)
      }
    case .ipv6:
      self.address = addressData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<CChar>) in
        inet_ntop(AF_INET6, bytes, &address, addressLength)
        return String(cString: address)
      }
    case .domain:
      if let address = String(bytes: addressData, encoding: .utf8) {
        self.address = address
      } else {
        return nil
      }
    }

    let port: UInt16 = portData.withUnsafeBytes { portPtr in
      var value: UInt16 = 0
      withUnsafeMutableBytes(of: &value) { valPtr in
        valPtr.copyMemory(from: UnsafeRawBufferPointer(rebasing: portPtr[0..<2]))
      }
      return value.bigEndian
    }
    
    self.port = port

    self.data = data
  }
}

class SOCKSProtocol: NWProtocolFramerImplementation {
  static var label: String { "SOCKS5" }
  static let definition = NWProtocolFramer.Definition(implementation: SOCKSProtocol.self)
  var clientVersion = UInt8(0)
  var bounded: Bool = false

  required init(framer: NWProtocolFramer.Instance) {}
  func wakeup(framer: NWProtocolFramer.Instance) { }
  func stop(framer: NWProtocolFramer.Instance) -> Bool { true }
  func cleanup(framer: NWProtocolFramer.Instance) { }

  func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
    .willMarkReady
  }

  func handleInput(framer: NWProtocolFramer.Instance) -> Int {
    while true {
      if clientVersion == 0 {
        return handshake(framer: framer)
      }
      if bounded {
        return pipe(framer: framer)
      }
      
      var tmpHeader: SOCKSMessageHeader? = nil
      // We request the long domain encoded version so we can have the address length as well.
      let headerSize = SOCKSMessageHeader.domainEncodedSize
      
      let parsed = framer.parseInput(minimumIncompleteLength: headerSize,
                                     maximumLength: headerSize) { (buffer, isComplete) -> Int in
        guard let buffer = buffer else {
          return 0
        }
        if buffer.count < headerSize {
          return 0
        }
        guard let header = SOCKSMessageHeader(buffer) else {
          return 0
        }

        tmpHeader = header
        if header.addressType == .domain {
          return headerSize
        }
        return header.encodedSize
      }

      guard parsed, let header = tmpHeader else {
        return headerSize
      }

      let message = NWProtocolFramer.Message(request: header.request!, addressType: header.addressType)

      if !framer.deliverInputNoCopy(length: Int(header.messageLength), message: message, isComplete: true) {
        return 0
      }
    }
  }

  func handshake(framer: NWProtocolFramer.Instance) -> Int {
    let handshakeSize = MemoryLayout<Int8>.size * 2
    
    // Ignore auth methods as an obscure feature that not even Chrome supports
    var tmpVersion:    UInt8? = nil,
        tmpAuthMethod: UInt8? = nil

    let parsed = framer.parseInput(minimumIncompleteLength: handshakeSize, maximumLength: handshakeSize+5) { (buffer, isComplete) -> Int in
      guard let buffer = buffer, buffer.count >= handshakeSize else {
        return 0
      }
      tmpVersion = buffer.load(fromByteOffset: 0, as: UInt8.self)
      let numAuthMethods = buffer.load(fromByteOffset: 1, as: UInt8.self)
      tmpAuthMethod = buffer.load(fromByteOffset: 2, as: UInt8.self)

      return handshakeSize + (MemoryLayout<Int8>.size * Int(numAuthMethods))
    }

    guard parsed, let version = tmpVersion, version == 0x05,
          let authMethod = tmpAuthMethod, authMethod == 0x00
          else {
      framer.markFailed(error: nil)
      return 0
    }
    
    clientVersion = version
    framer.writeOutput(data: Data([0x05, 0x00]))
    framer.markReady()
    return 0
  }

  func pipe(framer: NWProtocolFramer.Instance) -> Int {
    var tmpBuffer: Data? = nil
    let parsed = framer.parseInput(minimumIncompleteLength: 1, maximumLength: Int(INT_MAX)) { (buffer, isComplete) -> Int in
      guard let buffer = buffer, buffer.count > 0 else {
        return 0
      }
      tmpBuffer = Data(bytes: buffer.baseAddress!, count: buffer.count)
      return 0
    }
    
    guard parsed, let buffer = tmpBuffer else {
      return 0
    }
    
    let message = NWProtocolFramer.Message(definition: Self.definition)

    _ = framer.deliverInputNoCopy(
      length     : buffer.count,
      message: message,
      isComplete: false
    )
    return 0
  }
  
  func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
    if bounded {
      do {
        try framer.writeOutputNoCopy(length: messageLength)
      } catch let error {
        // TODO Log error or post somewhere.
        print("Hit error writing \(error)")
      }
      return
    }
    
    let domainLength: UInt8? = message.socksAddressType == .domain ? UInt8(messageLength - SOCKSMessage.portLength) : nil
    
    let header = SOCKSMessageHeader(reply: message.socksReply,
                                    addressType: message.socksAddressType,
                                    domainLength: domainLength)
    framer.writeOutput(data: header.encodedData)
    
    do {
      try framer.writeOutputNoCopy(length: messageLength)
    } catch let error {
      // TODO Log error or post somewhere.
      print("Hit error writing \(error)")
    }
    
    if message.socksReply == .succeeded {
      bounded = true
    }
  }
}

extension NWProtocolFramer.Message {
  convenience init(request: SOCKSRequestType, addressType: SOCKSAddressType) {
    self.init(definition: SOCKSProtocol.definition)
    self["SOCKSRequest"] = request
    self["SOCKSAddressType"] = addressType
  }
  
  convenience init(reply: SOCKSReplyType, addressType: SOCKSAddressType) {
    self.init(definition: SOCKSProtocol.definition)
    self["SOCKSReply"] = reply
    self["SOCKSAddressType"] = addressType
  }

  var socksRequest: SOCKSRequestType {
    return self["SOCKSRequest"] as! SOCKSRequestType
  }
  
  var socksReply: SOCKSReplyType {
    return self["SOCKSReply"] as! SOCKSReplyType
  }
  
  var socksAddressType: SOCKSAddressType {
    return self["SOCKSAddressType"] as! SOCKSAddressType
  }
}

extension NWParameters {
  static var SOCKS: NWParameters {
    let parameters = NWParameters.tcp
    let framerOptions = NWProtocolFramer.Options(definition: SOCKSProtocol.definition)
    parameters.defaultProtocolStack.applicationProtocols.insert(framerOptions, at: 0)
    
    return parameters
  }
}

public class SOCKSServer {
  let client: SSHClient
  var log: SSHLogger { get { client.log }}
  var listener: NWListener!
  let queue = DispatchQueue(label: "SOCKS")
  let port: NWEndpoint.Port

  public init(_ port: UInt16 = 1080, proxy client: SSHClient) throws {
    //listener.newConnectionHandler = { [weak self] in self?.handleConnectionUpdates($0) }
    //listener.stateUpdateHandler = { [weak self] in self?.handleListenerUpdates($0) }
    self.client = client
    guard let port = NWEndpoint.Port(rawValue: port) else {
      throw SOCKSError()
    }
    self.port = port

    try startListening()
  }

  func startListening() throws {
    self.listener = try NWListener(using: .SOCKS, on: self.port)

    listener.newConnectionHandler = { [weak self] in self?.handleNewConnection($0) }
    listener.stateUpdateHandler = { print("Listener \($0)") }
    listener.start(queue: queue)
  }

  func handleNewConnection(_ conn: NWConnection) {
    conn.stateUpdateHandler = { [weak self] state in
      guard let self = self else { return }

      self.log.message("SOCKS Server - Connection \(state)", SSH_LOG_DEBUG)
      switch state {
      case .ready:
        self.receiveNextMessage(conn)
      default:
        break
      }
    }
    
    conn.start(queue: queue)
  }

  func receiveNextMessage(_ conn: NWConnection) {
    conn.receiveMessage { (content, context, isComplete, error) in
      if let message = context?.protocolMetadata(definition: SOCKSProtocol.definition) as? NWProtocolFramer.Message,
         let content = content,
         let msg = SOCKSMessage(content, type: message.socksAddressType) {
        // We could offer a delegate call here instead, with the promise of reusability at one point.
        // Not important for us right now.

        var cancellable: AnyCancellable?
        var stream: Stream?

        print("Trying to connect to \(msg.address) on \(msg.port)")

        cancellable = self.client.requestForward(to: msg.address, port: Int32(msg.port),
                                                 from: "localhost", localPort: Int32(self.port.rawValue))
          .map { s -> SSH.Stream in
            // If the connection succeeds, reply
            let reply = NWProtocolFramer.Message(reply: .succeeded,
                                                 addressType: .ipv4)
            let context = NWConnection.ContentContext(identifier: "Reply", metadata: [reply])
            let localhost = IPv4Address("0.0.0.0")
            let data = localhost!.rawValue + Data([0x00, 0x00])
            conn.send(content: data, contentContext: context,
                      isComplete: true, completion: .idempotent)
            
            return s
          }
          .sink(receiveCompletion: { c in
            if case let .failure(error) = c {
              print("Could not process Forward Request to \(msg.address) \(error)")
              conn.cancel()
              cancellable = nil
              stream = nil
            }
          }, receiveValue: { s in
            print("SOCKS forward received - \(msg.address)")
            // TODO We could make the connect a sink.
            // Then the flow is clear and Stream does not need to be persisted.
            // This would be a big change, but we could test if while maintaining the previous interface.
            stream = s
            s.connect(stdout: conn, stdin: conn)
            s.handleCompletion = {
              stream = nil
              conn.cancel()
              cancellable = nil
            }
            s.handleFailure = { error in
              stream = nil
              conn.cancel()
              cancellable = nil
            }
          })
      }
    }
  }
}
