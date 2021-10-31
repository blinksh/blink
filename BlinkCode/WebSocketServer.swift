import Combine
import Foundation
import Network
import Security

let p12Cert = """
  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
  LN/Xy2AzvAQIwSGIMRRHzLwCAggA
  
  """
let pemCert = """
  -----BEGIN CERTIFICATE-----
  MIIEpDCCAowCCQCwoT5TbovoTTANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
  b2NhbGhvc3QwHhcNMjExMDIyMTYzNjE3WhcNMjIxMDIyMTYzNjE3WjAUMRIwEAYD
  VQQDDAlsb2NhbGhvc3QwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDE
  h14K/KK8o3VOumeaD8x5Zf13iWApq1Fx6rjRuKh1K7yrI53q38nw/Q1ul782lbxI
  iw8JaMiX4V6nPE+5Kej8LFyy98w46VsBnYs968AL42ordB3nPC8zwVbfPYrHv1oy
  +cBcmcULtq750fvWP1acCiBqdgMSnF0omSTkTU/D3lIUqpwgpQl2/VlhtpWlPyoM
  Aq4DO+Vmye9NUMOZQceApIb0sH6a0JrB5jD91h9sgVWayNMVxju7GziPBzmRiuMV
  wDD2rMjo7gFJLjB5XagTYXtiIpojzk5rKpZAxTktHYiP1poN/aHnqCjlmzvICR88
  8BL6JEfcj3p9NSIi344MagdWmRQt19bEXpEHVLJn2SAE/TvyNmchAevYtlsIaUDW
  Y1iabuxIA4QxWCAWteh/LPuLKP+hicVJ/mGZ1XVRKl6iVvUgDCJaPCJOcUnPZJxK
  bOvGkW87VeLaC39T30WDXaujhrBNTU2uDDZgcfWZs8DVimofKXUwkGVx4MROrntX
  +td2YqX6UKKYqXebkdgE1TSZeW82ECmwZo0n8C5jT8PUbGYk1Os4CSLYUasGQtHN
  UPP3yOv44eJ+4Af+ZS+XkUlEkC3UB0ZyiStzdpT7QDpNBsNgE7DZ6RyB7Q47Vxzn
  tj7l5kNbW2yrHWcqvTWBq3d8WP4oI6N13y1fjh1yrwIDAQABMA0GCSqGSIb3DQEB
  CwUAA4ICAQAA/PI4+iSy9zys2i/uJs7qtz/Omi0RJjnz9lKm1K1Cr7apedm8aIWm
  ZhRLFJt4LdchjqT+dAVH+E0Su1wiF5EafvRoXMEfHJ1BW7rXyZlrvvIyVtqxvAeN
  PfkHhyjPS7n5P2C7hHOEqmeQilbuagc28/HIVDdoXyXighjZWnHGGMPVCwpTPHbO
  OtjyU6HF5Dujv+8lFVr1tgdexfKnC9tm3puYO81rDDzENV9VHp18NqKznD5mLLYK
  Ngx2yyqJNxppJlenlP+1ryLd061EG/GnaiPJ65eaQKtz+mUXoWBnSeUZCUarxc5T
  OwyMU3OPGE5ZVgXAb6LlaGtOF3kzWCSDeWzZQnnlzrta1pkGw35OEEIZMngMfQTn
  edoo1PQQZqf9rAdFQd/c4m7HMPfnvxRlVt0sl55Q/B+vGdIfQOCxUtChaP+PZhjQ
  WlkLL6lBVfyrk+tDYny4pBpr+nBgaLUDHCZLFi5//SXUFvMH/98xj1VNQX1DGj/R
  GBgfOTsmbov33hOiR9l4jqbPW8lV0RRfnRVfdWT8Q6rrb3BARqwCtOcbp7CMpn2s
  j4MEhnQnIoFDIwV0kUbJDVIM2JNnv0OthZcJNqWPjPEdHwAhjYsa4O25zuBsVw1S
  VNRsYjq7Hbq4nYioPS6Og942BbwtjHTPf77ALvHZVDBVY0upPZXYvA==
  -----END CERTIFICATE-----
  """

extension String: Error {}

public class WebSocketServer {
  public typealias Response = (Data?, Data?)
  public typealias ResponsePublisher = AnyPublisher<Response, Error>
  var delegate: CodeSocketDelegate? = nil
  var cancellables = [UInt32:AnyCancellable]()
  let queue = DispatchQueue(label: "WebSocketServer")

  var listener: NWListener!
  
  public init(listenOn port: NWEndpoint.Port, tls: Bool) throws {
    try startListening(port, tls)
  }
  
  func startListening(_ port: NWEndpoint.Port, _ tls: Bool) throws {
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
    // TODO Review the state
    listener.stateUpdateHandler = { print("WebSocket Listener \($0)") }
    listener.start(queue: queue)
  }
  
  func tlsOptions() throws -> NWProtocolTLS.Options {
    let tlsOptions = NWProtocolTLS.Options()
    guard let p12Data = Data(base64Encoded: p12Cert.replacingOccurrences(of: "\n", with: "")) else {
      throw "Could not read P12 b64 encoded"
    }
    var rawItems: CFArray?
    // Empty password did not work
    let options = [ kSecImportExportPassphrase as String: "asdf" ]
    let status = SecPKCS12Import(p12Data as NSData,
                                 options as CFDictionary,
                                 &rawItems)
    guard status == errSecSuccess else { throw "Could not generate Identity from PKCS12" }
    
    let items = rawItems! as! Array<Dictionary<String, Any>>
    let firstItem = items[0]
    
    guard let secIdentity = firstItem[kSecImportItemIdentity as String] as! SecIdentity? else {
      throw "No identity found"
    }
    if let identity = sec_identity_create(secIdentity) {
      sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
      sec_protocol_options_set_max_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv13)
      sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, identity)
//      sec_protocol_options_append_tls_ciphersuite( tlsOptions.securityProtocolOptions, tls_ciphersuite_t(rawValue: UInt16(TLS_AES_128_GCM_SHA256))! )
    }
    
    return tlsOptions
  }
  func handleNewConnection(_ conn: NWConnection) {
    // TODO Skipping on the statehandler for the connection for now
    //connections.append(conn)
    WebSocketConnection(conn, delegate).receiveNextMessage()
  }
}

class WebSocketConnection {
  let conn: NWConnection
  let delegate: CodeSocketDelegate?
  let queue = DispatchQueue(label: "WebSocketServer")
  var cancellables = [UInt32:AnyCancellable]()

  init(_ conn: NWConnection, _ delegate: CodeSocketDelegate?) {
    self.conn = conn
    self.delegate = delegate
    conn.start(queue: queue)
  }
  
  func receiveNextMessage() {
    conn.stateUpdateHandler = { print("Connection state update - \($0)")}
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
    // The combine flows can be cancelled.
    // These must be done by the one keeping track of the "action" itself.
    // We are going to make it rest right here, at the server. But it could be moved
    // one level up, to the Delegate.
    var buffer = data
    // TODO Check header size, otherwise the server will crash.
    guard let header = CodeSocketMessageHeader(buffer[0..<CodeSocketMessageHeader.encodedSize]) else {
      // TODO Throw Wrong header
      print("Wrong header")
      return
    }
    buffer = data.advanced(by: CodeSocketMessageHeader.encodedSize)
    
    // TODO Cancel the message if it is a cancellable type.
    // TODO If the message has error type, then throw Invalid Request error.
    let messageHeaderTypes: [CodeSocketContentType] = [.Json, .Binary, .JsonWithBinary]
    guard messageHeaderTypes.contains(header.type) else {
      print("Wrong message type")
      return
    }
    
    let operationId = header.operationId
    guard let payload = CodeSocketMessagePayload(buffer, type: header.type) else {
      // TODO Throw invalid payload content
      print("Invalid payload")
      return
    }
    
    guard let delegate = delegate else {
      return
    }
    
    // TODO Separate the SendMessage. For errors, map and send a message as usual.
    // For completion, call the same removal as during cancel.
    cancellables[operationId] = delegate
      .handleMessage(encodedData: payload.encodedData,
                     binaryData:  payload.binaryData)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          print("Error completing operation - \(error)")
          if case is CodeFileSystemError = error {
            self.sendError(operationId: operationId,
                           error: error as! CodeFileSystemError)
          }
        case .finished:
          // TODO Remove the cancellable
          break
        }
      },
            receiveValue: {
        self.sendMessage(operationId: operationId,
                         encodedData: $0,
                         binaryData: $1)
      })
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
