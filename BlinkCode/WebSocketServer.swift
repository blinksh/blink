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
import Security


public class WebSocketServer {
  public typealias Response = (Data?, Data?)
  public typealias ResponsePublisher = AnyPublisher<Response, Error>
  var delegate: CodeSocketDelegate? = nil
  var cancellables = [UInt32:AnyCancellable]()
  let queue = DispatchQueue(label: "WebSocketServer")
  let port: NWEndpoint.Port
  let tls: Bool
  var listenerMonitor: BackgroundTaskMonitor? = nil
  let log: BlinkLogger = CodeFileSystemLogger.log("CodeWebSocketServer")
  var listener: NWListener!
  
  public init(listenOn port: NWEndpoint.Port, tls: Bool) throws {
    self.port = port
    self.tls = tls
    self.listenerMonitor = BackgroundTaskMonitor(start: { [weak self] in self?.startListening()  },
                                                 stop:  { [weak self] in
      self?.log.info("Suspending WebSocket")
      self?.listener.cancel()
    })
  }
  
  func startListening() {
    do {
      log.info("Starting WebSocket...")
      let parameters: NWParameters
      if tls {
        parameters = NWParameters(tls: try tlsOptions())
      } else {
        parameters = NWParameters.tcp
      }
      let websocketOptions = NWProtocolWebSocket.Options()
      parameters.defaultProtocolStack.applicationProtocols.insert(websocketOptions, at: 0)
      
      self.listener = try NWListener(using: parameters, on: port)
      
      listener.newConnectionHandler = { [weak self] in self?.handleNewConnection($0) }
      listener.stateUpdateHandler = { [weak self] in self?.handleStateUpdate($0) }
      listener.start(queue: queue)
    } catch {
      self.delegate?.finished(error)
    }
  }
  
  func handleStateUpdate(_ newState: NWListener.State) {
    log.info("WebSocket Listener \(newState)")
    if case .failed(let error) = newState {
      // If the listener fails, re-start.
      if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
        log.error("Listener failed with \(error), restarting")
        listener.cancel()
        self.startListening()
      } else {
        listener.cancel()
        listenerMonitor = nil
        self.delegate?.finished(error)
      }
    }
  }
  
  func tlsOptions() throws -> NWProtocolTLS.Options {
    let tlsOptions = NWProtocolTLS.Options()
    let p12Data = Data(base64Encoded: p12Cert.replacingOccurrences(of: "\n", with: ""))!
    var rawItems: CFArray?
    // Empty password did not work
    let options = [ kSecImportExportPassphrase as String: "asdf" ]
    let _ = SecPKCS12Import(p12Data as NSData,
                            options as CFDictionary,
                            &rawItems)
    //guard status == errSecSuccess else { throw "Could not generate Identity from PKCS12" }
    
    let items = rawItems! as! Array<Dictionary<String, Any>>
    let firstItem = items[0]
    
    let secIdentity = firstItem[kSecImportItemIdentity as String] as! SecIdentity

    if let identity = sec_identity_create(secIdentity) {
      sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
      sec_protocol_options_set_max_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv13)
      sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, identity)
//      sec_protocol_options_append_tls_ciphersuite( tlsOptions.securityProtocolOptions, tls_ciphersuite_t(rawValue: UInt16(TLS_AES_128_GCM_SHA256))! )
    }
    
    return tlsOptions
  }
  
  func handleNewConnection(_ conn: NWConnection) {
    WebSocketConnection(conn, delegate).receiveNextMessage()
  }
}

class WebSocketConnection {
  let conn: NWConnection
  let delegate: CodeSocketDelegate?
  let queue = DispatchQueue(label: "WebSocketServer")
  let log: BlinkLogger
  var cancellables = [UInt32:AnyCancellable]()

  init(_ conn: NWConnection, _ delegate: CodeSocketDelegate?) {
    self.conn = conn
    self.delegate = delegate
    self.log = CodeFileSystemLogger.log("Connection \(conn.currentPath!.remoteEndpoint!.debugDescription)")
    conn.start(queue: queue)
  }
  
  func receiveNextMessage() {
    conn.stateUpdateHandler = { newState in
      self.log.info("Connection state update - \(newState)")
      if case .failed(let error) = newState {
        self.log.error("Connection failed - \(error)")
        self.conn.cancel()
        // TODO if we associate to the translator, we need to notify the delegate.
      }
    }
    conn.receiveMessage { (content, context, isComplete, error) in
      if let data = content,
         let context = context {
        if let metadata = context.protocolMetadata as?  [NWProtocolWebSocket.Metadata],
           metadata[0].opcode == .ping {
          self.handlePing(data: data)
        } else {
          self.handleMessage(data: data)
        }
        self.receiveNextMessage()
      }
    }
  }
  
  func handlePing(data: Data) {
    // Return a pong with the same data
    let metadata = NWProtocolWebSocket.Metadata(opcode: .pong)
    let context = NWConnection.ContentContext(identifier: "pongContext",
                                              metadata: [metadata])
    conn.send(content: data, contentContext: context, completion: .idempotent)
  }
  
  func handleMessage(data: Data) {
    var buffer = data

    // Log errors if malformed as this is just our service.    
    guard buffer.count >= CodeSocketMessageHeader.encodedSize,
          let header = CodeSocketMessageHeader(buffer[0..<CodeSocketMessageHeader.encodedSize]) else {
            self.log.error("Wrong header")
            return
    }
    buffer = data.advanced(by: CodeSocketMessageHeader.encodedSize)
    
    let messageHeaderTypes: [CodeSocketContentType] = [.Json, .Binary, .JsonWithBinary]
    guard messageHeaderTypes.contains(header.type) else {
      log.error("Wrong message type")
      return
    }
    
    let operationId = header.operationId
    guard let payload = CodeSocketMessagePayload(buffer, type: header.type) else {
      log.error("Invalid payload")
      return
    }
    
    guard let delegate = delegate else {
      return
    }
    
    // For completion, call the same removal as during cancel.
    cancellables[operationId] = delegate
      .handleMessage(encodedData: payload.encodedData,
                     binaryData:  payload.binaryData)
      .sink(
        receiveCompletion: { [weak self] completion in
          switch completion {
          case .failure(let error):
            self?.log.error("Error completing operation - \(error)")
            if case is CodeFileSystemError = error {
              self?.sendError(operationId: operationId,
                             error: error as! CodeFileSystemError)
            }
          case .finished:
            self?.cancellables.removeValue(forKey: operationId)
            break
          }
        },
        receiveValue: {
          self.sendMessage(operationId: operationId,
                           encodedData: $0,
                           binaryData: $1)
        }
      )
  }
  
  func sendMessage(operationId: UInt32,
                   encodedData: Data?,
                   binaryData: Data?) {
    let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
    let context = NWConnection.ContentContext(identifier: "binaryContext",
                                              metadata: [metadata])
    
    let payload = CodeSocketMessagePayload(encodedData: encodedData, binaryData: binaryData)
    
    let replyHeader = CodeSocketMessageHeader(type: payload.type,
                                              operationId: operationId,
                                              referenceId: operationId)
    conn.send(content: replyHeader.encoded + payload.encoded,
              contentContext: context,
              completion: .idempotent)
  }
  
  func sendError(operationId: UInt32,
                 error: CodeFileSystemError) {
    let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
    let context = NWConnection.ContentContext(identifier: "binaryContext",
                                              metadata: [metadata])
    
    let encodedData = try? JSONEncoder().encode(error)
    let payload = CodeSocketMessagePayload(encodedData: encodedData)
    
    let replyHeader = CodeSocketMessageHeader(type: .Error,
                                              operationId: operationId,
                                              referenceId: operationId)
    conn.send(content: replyHeader.encoded + payload.encoded,
              contentContext: context,
              completion: .idempotent)
  }
}

extension Data {
  fileprivate init(_ int: UInt32) {
    var val: UInt32 = UInt32(bigEndian: int)
    self.init(bytes: &val, count: MemoryLayout<UInt32>.size)
  }
  fileprivate init(_ int: UInt8) {
    var val: UInt8 = UInt8(int)
    self.init(bytes: &val, count: MemoryLayout<UInt8>.size)
  }
}

extension UInt32 {
  fileprivate static func decode(_ data: inout Data) -> UInt32 {
    let size = MemoryLayout<UInt32>.size
    let val = UInt32(bigEndian: data[0..<size].withUnsafeBytes { bytes in
      bytes.load(as: UInt32.self)
    })
    if data.count == size {
      data = Data()
    } else {
      data = data.advanced(by: size)
    }
    return val
  }
}

extension UInt8 {
  fileprivate static func decode(_ data: inout Data) -> UInt8 {
    let size = MemoryLayout<UInt8>.size
    let val = UInt8(data[0..<size].withUnsafeBytes { bytes in
      bytes.load(as: UInt8.self)
    })
    if data.count == size {
      data = Data()
    } else {
      data = data.advanced(by: size)
    }
    return val
  }
}

protocol CodeSocketDelegate {
  func handleMessage(encodedData: Data, binaryData: Data?) -> WebSocketServer.ResponsePublisher
  func finished(_ error: Error?)
}

struct CodeSocketMessageHeader {
  static var encodedSize: Int { (MemoryLayout<UInt32>.size * 2) + MemoryLayout<UInt8>.size }
  
  let type: CodeSocketContentType
  let operationId: UInt32
  let referenceId: UInt32
  
  init(type: CodeSocketContentType, operationId: UInt32, referenceId: UInt32) {
    self.type = type
    self.operationId = operationId
    self.referenceId = referenceId
  }
  
  init?(_ data: Data) {
    var buffer = data
    guard let type = CodeSocketContentType(rawValue: UInt8.decode(&buffer)) else {
      return nil
    }
    self.type = type
    self.operationId = UInt32.decode(&buffer)
    self.referenceId = UInt32.decode(&buffer)
  }
  
  public var encoded: Data {
    Data(type.rawValue) + Data(operationId) + Data(referenceId)
  }
}

struct CodeSocketMessagePayload {
  let encodedData:   Data
  let binaryData:    Data?
  
  init?(_ data: Data, type: CodeSocketContentType) {
    var buffer = data
    var encodedData = Data()
    var binaryData: Data? = nil
    
    var encodedLength: UInt32 = 0
    if type == .JsonWithBinary || type == .Json {
      if type == .JsonWithBinary {
        encodedLength = UInt32.decode(&buffer)
      } else {
        encodedLength = UInt32(buffer.count)
      }
      encodedData = buffer[0..<encodedLength]
    }
    
    if type == .JsonWithBinary || type == .Binary {
      // Advance only if we know there is further information
      buffer = buffer.advanced(by: Int(encodedLength))
      binaryData = buffer
    }
    
    self.encodedData = encodedData
    self.binaryData = binaryData
  }
  
  init(encodedData: Data?, binaryData: Data? = nil) {
    self.encodedData = encodedData ?? Data()
    self.binaryData  = binaryData
  }
  
  var type: CodeSocketContentType {
    if !encodedData.isEmpty, let _ = binaryData {
      return .JsonWithBinary
    } else if let _ = binaryData {
      return .Binary
    } else {
      // NOTE An empty message is still an empty JSON message
      return .Json
    }
  }
  
  var encoded: Data {
    switch type {
    case .JsonWithBinary:
      return Data(UInt32(encodedData.count)) + encodedData + binaryData!
    case .Json:
      return encodedData
    case .Binary:
      return binaryData!
    default:
      return Data()
    }
  }
}

enum CodeSocketContentType: UInt8 {
  case Cancel = 1
  case Binary
  case Json
  case JsonWithBinary
  case Error
}
