//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2021 Blink Mobile Shell Project
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

typealias SSHConnection = AnyPublisher<ssh_session, Error>
typealias SSHChannel = AnyPublisher<ssh_channel, Error>

public func SSHInit() {
  ssh_init()
}

// TODO: check libssh api for string values
fileprivate extension ssh_options_e {
  var name: String {
    switch self {
    case SSH_OPTIONS_HOST:              return "SSH_OPTIONS_HOST"
    case SSH_OPTIONS_USER:              return "SSH_OPTIONS_USER"
    case SSH_OPTIONS_LOG_VERBOSITY:     return "SSH_OPTIONS_LOG_VERBOSITY"
    case SSH_OPTIONS_COMPRESSION_C_S:   return "SSH_OPTIONS_COMPRESSION_C_S"
    case SSH_OPTIONS_COMPRESSION_S_C:   return "SSH_OPTIONS_COMPRESSION_S_C"
    case SSH_OPTIONS_COMPRESSION:       return "SSH_OPTIONS_COMPRESSION"
    case SSH_OPTIONS_COMPRESSION_LEVEL: return "SSH_OPTIONS_COMPRESSION_LEVEL"
    case SSH_OPTIONS_PORT_STR:          return "SSH_OPTIONS_PORT_STR"
    case SSH_OPTIONS_PROXYJUMP:         return "SSH_OPTIONS_PROXYJUMP"
    case SSH_OPTIONS_PROXYCOMMAND:      return "SSH_OPTIONS_PROXYCOMMAND"
    case SSH_OPTIONS_SSH_DIR:           return "SSH_OPTIONS_SSH_DIR"
    default:                            return "raw: \(rawValue)"
    }
  }
}

// This is a macro in libssh, so we redefine it here
// https://stackoverflow.com/questions/24662864/swift-how-to-use-sizeof
func ssh_init_callbacks(_ cb: inout ssh_callbacks_struct) {
  cb.size = MemoryLayout.size(ofValue: cb)
}

func ssh_init_channel_callbacks(_ cb: inout ssh_channel_callbacks_struct) {
  cb.size = MemoryLayout.size(ofValue: cb)
}

/**
 Delegates the responsability of interpreting a "Yes"/"Si"/"да" to the app.
 Should return a `.affirmative` if it's a positive answer.
 */
public enum InteractiveResponse {
  /// "Yes"/"Si"/"да"
  case affirmative
  /// "No"/"No"/"нет"
  case negative
}

/**
 Delegates the responsability of implementing and handling the cases.
 */
public enum VerifyHost {
  case changed(serverFingerprint: String)
  case unknown(serverFingerprint: String)
  case notFound(serverFingerprint: String)
}

public struct SSHClientConfig: CustomStringConvertible {
  let user: String
  let port: String
  
  public typealias RequestVerifyHostCallback = (VerifyHost) -> AnyPublisher<InteractiveResponse, Error>
  
  /**
   List of all of the authentication methods to use. Priority in which they are tried is not tied to their position on the list, defined in `SSHClient.validAuthMethods()`.
   1. Publickey
   2. Password
   3. Keyboard Interactive
   4. Hostbased
   */
  var authenticators: [Authenticator] = []
  var agent: SSHAgent?

  /// `.ssh` path location
  let sshDirectory: String?
  /// Path to config file
  let sshClientConfigPath: String?
  /// If `nil` no host verification will be done
  let requestVerifyHostCallback: RequestVerifyHostCallback?
  
  let logger: SSHLoggerPublisher?
  /// Default verbosity logging is disabled, SSH_LOG_NOLOG
  let loggingVerbosity: SSHLogLevel
  
  let keepAliveInterval: Int? = nil
  
  let proxyCommand: String?
  let proxyJump: String?
  
  let connectionTimeout: Int
  
  let compression: Bool
  let compressionLevel: Int
  
  public var description: String { """
  user: \(user)
  port: \(port)
  authenticators: \(authenticators.map { $0.displayName }.joined(separator: ", "))
  proxyJump: \(proxyJump)
  proxyCommand: \(proxyCommand)
  compression: \(compression)
  compressionLevel: \(compressionLevel)
  """}

  /**
   - Parameters:
   - user:
   - port: Default will be `22`
   - authMethods: Different authentication methods to try
   - loggingVerbosity: Default LibSSH logging shown is `SSH_LOG_NOLOG`
   - verifyHostCallback:
   - terminalEmulator:
   - sshDirectory: `ssh` directory, if `nil` it will use the default directory
   - keepAliveInterval: if `nil` it won't send KeepAlive packages from Client to the Server
   */
  public init(user: String,
              port: String = "22",
              proxyJump: String? = nil,
              proxyCommand: String? = nil,
              authMethods: [AuthMethod]? = nil,
              agent: SSHAgent? = nil,
              loggingVerbosity: SSHLogLevel = .none,
              verifyHostCallback: RequestVerifyHostCallback? = nil,
              connectionTimeout: Int = 30,
              sshDirectory: String? = nil,
              sshClientConfigPath: String? = nil,
              logger: PassthroughSubject<String, Never>? = nil,
              keepAliveInterval: Int? = nil,
              compression: Bool = true,
              compressionLevel: Int = 6) {
    // We do our own constructor because the automatic one cannot define optional params.
    self.user = user
    self.port = port
    self.proxyCommand = proxyCommand
    self.proxyJump = proxyJump
    self.agent = agent
    self.loggingVerbosity = loggingVerbosity
    self.requestVerifyHostCallback = verifyHostCallback
    self.sshDirectory = sshDirectory
    self.sshClientConfigPath = sshClientConfigPath
    self.logger = logger
    self.connectionTimeout = connectionTimeout
    self.compression = compression
    self.compressionLevel = compressionLevel
    
    // TODO Disable Keep Alive for now. LibSSH is not processing correctly the messages
    // that may come back from the server.
    // self.keepAliveInterval = keepAliveInterval
    
    authMethods?.forEach({ auth in
      if let auth = (auth as? Authenticator) {
        self.authenticators.append(auth)
      }
    })
  }
}

public class SSHClient {
  let session: ssh_session
  let host: String
  let options: SSHClientConfig
  let log: SSHLogger
  
  public typealias ExecProxyCommandCallback = (String, Int32, Int32) -> Void
  let proxyCb: ExecProxyCommandCallback?
  
  let rloop: RunLoop
  var callbacks: ssh_callbacks_struct
  var reversePorts: [Int32: PassthroughSubject<Stream, Error>] = [:]
  
  var keepAliveTimer: Timer?
  
  var isConnected: Bool {
    ssh_is_connected(session) == 1
  }

  // When a connection is local, we consider it trusted and we use this flag to indicate that
  // to the agent. On an untrusted connection, the Agent may decide not to use specific keys.
  var trustAgentConnection: Bool = true
  
  public struct PTY {
    let rows: Int32
    let columns: Int32
    let emulator: String
    
    public init(rows: Int32 = 80, columns: Int32 = 24, emulator: String = "xterm-256color") {
      self.rows = rows
      self.columns = columns
      self.emulator = emulator
    }
  }
  
  public var handleSessionException: ((Error) -> ())?
  
  /**
   Passes LibSSH values down the stream to so the client app would present in whichever form it's needed
   */
  let loggingCallback: ssh_logging_callback = { (priority, function, buffer, userdata) in
    
    let ctxt = Unmanaged<SSHClient>.fromOpaque(userdata!).takeUnretainedValue()
    
    guard let message = String(cString: buffer!, encoding: .utf8) else { return }
    
    ctxt.log.message(message, priority)
  }
  
  
  private init(to host: String, with opts: SSHClientConfig, proxyCb: ExecProxyCommandCallback?) throws {
    
    self.log = SSHLogger(verbosity: opts.loggingVerbosity, logger: opts.logger)
    
    guard let session = ssh_new() else {
      throw SSHError(title: "Could not create session object")
    }
    
    ssh_set_blocking(session, 0)
    
    self.options = opts
    self.session = session
    self.host = host
    self.proxyCb = proxyCb
    
    self.rloop = RunLoop.current
    
    self.callbacks = ssh_callbacks_struct()
    
    guard setupCallbacks() == SSH_OK else {
      throw SSHError(title: "Could not setup callbacks for session")
    }
    
    ssh_set_log_callback(loggingCallback)
    
    var verbosity = options.loggingVerbosity.rawValue
    try _setSessionOption(SSH_OPTIONS_HOST, host)
    try _setSessionOption(SSH_OPTIONS_USER, opts.user)
    try _setSessionOption(SSH_OPTIONS_LOG_VERBOSITY, &verbosity)
    
  
    // NOTE: libssh SSH_OPTIONS_COMPRESSION yes/no differs from OpenSSH:
    // - OpenSSH keeps 'none' value in the list, just change it's position
    // - LibSSH removes 'none'
    let preferredCompressionAlgoList = opts.compression
      ? "zlib@openssh.com,zlib,none"
      : "none,zlib@openssh.com,zlib"

    try _setSessionOption(SSH_OPTIONS_COMPRESSION_C_S, preferredCompressionAlgoList)
    try _setSessionOption(SSH_OPTIONS_COMPRESSION_S_C, preferredCompressionAlgoList)

    var compressionLevel = opts.compressionLevel
    try _setSessionOption(SSH_OPTIONS_COMPRESSION_LEVEL, &compressionLevel)
    
    try _setSessionOption(SSH_OPTIONS_PORT_STR, options.port)
    
    if let proxyJump = options.proxyJump, !proxyJump.isEmpty {
      try _setSessionOption(SSH_OPTIONS_PROXYJUMP, options.proxyJump)
    }
    else if let proxyCommand = options.proxyCommand, !proxyCommand.isEmpty {
      try _setSessionOption(SSH_OPTIONS_PROXYCOMMAND, options.proxyCommand)
    }
    
    /// If `nil` it uses the default `.ssh` directory
    if options.sshDirectory != nil {
      try _setSessionOption(SSH_OPTIONS_SSH_DIR, options.sshDirectory)
    }
    
    /// Parse `~/.ssh/config` file.
    /// This should be the last call of all options, it may overwrite options which are already set.
    /// It requires that the host name is already set with ssh_options_set_host().
    guard
      ssh_options_parse_config(session, options.sshClientConfigPath) == SSH_OK
    else {
      throw SSHError(title: "Could not parse config file at \(self.options.sshClientConfigPath ?? "<nil>") for session")
    }
  }
  
  private func _setSessionOption(_ option: ssh_options_e, _ value: UnsafeRawPointer!) throws {
    guard
      ssh_options_set(session, option, value) == SSH_OK
    else {
      throw SSHError(title: "Failed to set option '\(option.name)'");
    }
  }
  
  func startKeepAliveTimer() {
    // https://github.com/golang/go/issues/4552
    keepAliveTimer?.invalidate()
    keepAliveTimer = Timer(timeInterval: 15, target: self, selector: #selector(onServerKeepAlive), userInfo: nil, repeats: true)
    rloop.add(keepAliveTimer!, forMode: .default)
  }
  
  @objc private func onServerKeepAlive() {
    guard isConnected else {
      return
    }
    
    let rc = ssh_client_send_keepalive(session)
    if rc != SSH_OK {
      keepAliveTimer?.invalidate()
      print("ERROR Keep alive")
    }
  }
  
  func setupCallbacks() -> Int32 {
    let ctxt = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    callbacks.userdata = ctxt
    
    log.message("Setting up connection callbacks.", SSH_LOG_DEBUG)
    ssh_set_log_userdata(ctxt)
    ssh_init_callbacks(&callbacks)
    
    callbacks.session_exception_function = { (session, userdata) in
      // Pass the callback to the other side, and let that wrap up this
      // connection, but also start a new one if necessary.
      let ctxt = Unmanaged<SSHClient>.fromOpaque(userdata!).takeUnretainedValue()
      let error = SSHError(title: "Session Exception", forSession: session)
      ctxt.log.message("\(error)", SSH_LOG_WARN)
      ctxt.handleSessionException?(error)
    }
    
    if options.proxyCommand != nil || options.proxyJump != nil {
      callbacks.set_proxycommand_function = { (cmd, inSock, outSock, userdata) in
        let ctxt = Unmanaged<SSHClient>.fromOpaque(userdata!).takeUnretainedValue()
        let command = String(cString: cmd!)
        // Will break if unconfigured. It can be considered
        // a code error.
        return ctxt.proxyCb!(command, inSock, outSock)
      }
    }
    
    return ssh_set_callbacks(session, &callbacks)
  }
  
  func connection() -> SSHConnection {
    AnyPublisher
      .just(self.session)
      .subscribe(on: rloop)
      .eraseToAnyPublisher()
  }
  
  func newChannel() -> SSHChannel {
    guard let channel = ssh_channel_new(self.session) else {
      return .fail(error: SSHError(title: "Could not create channel"))
    }
    ssh_channel_set_blocking(channel, 0)
    return Just(channel)
      .setFailureType(to: Error.self)
      .subscribe(on: rloop)
      .eraseToAnyPublisher()
  }
  
  public static func dial(_ host: String, with opts: SSHClientConfig, withProxy proxyCb: ExecProxyCommandCallback? = nil) -> AnyPublisher<SSHClient, Error> {
    // TODO We could enforce here some constraints, like we need a proxyCb
    // if there is a ProxyCommand in the opts.
    let c: SSHClient
    do {
      c = try SSHClient(to: host, with: opts, proxyCb: proxyCb)
    } catch {
      return .fail(error: error)
    }
    
    if let agent = opts.agent {
      agent.attachTo(client: c)
    }

    // Done this way we don't have to handle cancellations here.
    
    // A maybe better option is to let these handle the Client, and then let the internal
    // Client handle the session publishers.
    return c.connect()
      .flatMap { client -> AnyPublisher<SSHClient, Error> in
        client.log.message("Connection succeeded...", SSH_LOG_INFO)
        
        if client.options.requestVerifyHostCallback != nil {
          return client.verifyKnownHost()
        }
        return .just(client)
      }
      .flatMap{ $0.auth() }
      .flatMap{ client -> AnyPublisher<SSHClient, Error> in
        // If we logged in to the remote, agent requests may be remote and cannot be trusted
        client.trustAgentConnection = false

        if client.options.keepAliveInterval != nil {
          client.startKeepAliveTimer()
        }
        return .just(client)
      }
      // If cancelled, the connection will be closed without being passed to the user or
      // once the command is dumped.
      .eraseToAnyPublisher()
    
  }
  
  /**
   Get the current IP address of the connected session.
   
   - Returns: `String` containing the IP address, nil if it failed
   */
  public func clientAddressIP() -> String? {
    // Get the file descriptor for the current session
    let socketFd = ssh_get_fd(session)
    
    // Get the remote address for that file descriptor
    var addr: sockaddr_storage = sockaddr_storage()
    var addr_len: socklen_t = socklen_t(MemoryLayout.size(ofValue: addr))
    
    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    
    
    // Make local copy to avoid: "Overlapping accesses to 'addr', but modification requires exclusive access; consider copying to a local variable"
    let addrLen = addr.ss_len
    
    withUnsafeMutablePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        if getpeername(socketFd, $0, &addr_len) != 0 { return }
        
        getnameinfo($0, socklen_t(addrLen), &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST)
      }
    }
    
    return String(cString: hostBuffer, encoding: .utf8)
  }
  
  /**
   Check if the servers public key for the connected session is known. This checks if we already know the public key of the server we want to connect to. This allows to detect if there is a MITM attach going on of if there have been changes on the server we don't know about.
   */
  public func verifyKnownHost() -> AnyPublisher<SSHClient, Error> {
    var serverPublicKey: ssh_key? = nil
    var hash: UnsafeMutablePointer<UInt8>? = nil
    var hlen: size_t = -1;
    
    // None of the calls here require to contact the server, so we can do them without wrapping.
    let rc = ssh_get_server_publickey(session, &serverPublicKey)
    if rc < 0 {
      return .fail(error: SSHError(title: "Could not get server publickey"))
    }
    
    let state = ssh_get_publickey_hash(serverPublicKey, SSH_PUBLICKEY_HASH_SHA256, &hash, &hlen)
    if state < 0 {
      return .fail(error: SSHError(title: "Could not get server publickey hash"))
    }
    
    let hexString = String(cString: ssh_get_hexa(hash, hlen))
    ssh_clean_pubkey_hash(&hash)
    
    let rc3 = ssh_session_is_known_server(session)
    switch rc3 {
    case SSH_KNOWN_HOSTS_OK:
      return .just(self)
      
    case SSH_KNOWN_HOSTS_CHANGED:
      return self.options.requestVerifyHostCallback!(.changed(serverFingerprint: hexString)).flatMap { answer -> AnyPublisher<SSHClient, Error> in
        if answer == .affirmative {
          let rc = ssh_session_update_known_hosts(self.session)
          if rc != SSH_OK {
            return .fail(error: SSHError(title: "Could not update known_hosts file."))
          }
          return .just(self)
        }
        
        return .fail(error: SSHError(title: "Could not verify host authenticity."))
      }.eraseToAnyPublisher()
      
    case SSH_KNOWN_HOSTS_UNKNOWN:
      return self.options.requestVerifyHostCallback!(.unknown(serverFingerprint: hexString)).flatMap { answer -> AnyPublisher<SSHClient, Error> in
        if answer == .affirmative {
          let rc = ssh_session_update_known_hosts(self.session)
          
          if rc < 0 {
            return .fail(error: SSHError(title: "Error updating known_hosts file."))
          }
          
          return .just(self)
        }
        
        return .fail(error: SSHError(title: "Could not verify host authenticity."))
      }.eraseToAnyPublisher()
      
      
    /// The server gave use a key of a type while we had an other type recorded. It is a possible attack.
    case SSH_KNOWN_HOSTS_OTHER:
      // Stop connection because we could not verify the authenticity. And we could make the other side dispaly it.
      return .fail(error: SSHError(title: "The server gave use a key of a type while we had an other type recorded. It is a possible attack."))
    /// There had been an eror checking the host.
    case SSH_KNOWN_HOSTS_ERROR:
      return .fail(error: SSHError(title: "Could not verify host authenticity."))
    /// The known host file does not exist. The host is thus unknown. File will be created if host key is accepted
    case SSH_KNOWN_HOSTS_NOT_FOUND:
      return self.options.requestVerifyHostCallback!(.notFound(serverFingerprint: hexString)).flatMap { answer -> AnyPublisher<SSHClient, Error> in
        if answer == .affirmative {
          let rc = ssh_session_update_known_hosts(self.session)
          
          if rc != SSH_OK {
            return .fail(error: SSHError(title: "Error updating known_hosts file."))
          }
          
          return .just(self)
        }
        
        return .fail(error: SSHError(title: "Could not verify host authenticity."))
      }.eraseToAnyPublisher()
      
    default:
      return .fail(error: SSHError(title: "Unknown code received during host key exchange. Possible library error."))
    }
  }
  
  public func connect() -> AnyPublisher<SSHClient, Error> {
    var timerFired = false
    var timer: Timer?
    return connection()
      .map { conn -> ssh_session in
        // Set timeout if it is configured.
        // We are already in the runloop, so rw is thread-safe.
        let timeout = self.options.connectionTimeout
        timer = Timer.scheduledTimer(
          withTimeInterval: Double(timeout),
          repeats: false) {_ in timerFired = true }
        return conn
      }
      .eraseToAnyPublisher()
      .tryOperation { session in
        if timerFired {
          throw SSHError(title: "Connection to \(self.host) timed out.")
        }
        self.log.message("Starting connection to \(self.host)", SSH_LOG_INFO)
        let rc = ssh_connect(session)
        
        if rc != SSH_OK {
          throw SSHError(rc, forSession: session)
        } else {
          timer?.invalidate()
        }
        
        return self
      }
  }
  
  /**
   Returns list of compatible Auth Methods with the host to be connected. Defines the priorities in which they're gonna be attempted.
   */
  func validAuthMethods() -> [Authenticator] {
    var authMethods: [Authenticator] = []
    
    func appendMethod(_ name: String) {
      for method in self.options.authenticators {
        if method.name() == name {
          authMethods.append(method)
        }
      }
    }
    
    let methods = ssh_userauth_list(session, nil)
    
    if ((methods & Int32(bitPattern: SSH_AUTH_METHOD_PUBLICKEY)) != 0) {
      appendMethod("publickey")
    }
    if ((methods & Int32(bitPattern: SSH_AUTH_METHOD_PASSWORD)) != 0) {
      appendMethod("password")
    }
    if ((methods & Int32(bitPattern: SSH_AUTH_METHOD_INTERACTIVE)) != 0) {
      appendMethod("keyboard-interactive")
    }
    if ((methods & Int32(bitPattern: SSH_AUTH_METHOD_HOSTBASED)) != 0) {
      appendMethod("hostbased")
    }
    
    
    return authMethods
  }
  
  func auth() -> AnyPublisher<SSHClient, Error> {
    // Return the Client if any method worked, otherwise return an error
    func tryAuth(_ methods: [Authenticator],  tried: [Authenticator]) -> AnyPublisher<SSHClient, Error> {
      if methods.count == 0 {
        return .fail(error: SSHError.authError(msg: "Could not authenticate, no valid methods to try."))
      }
      
      let method = methods.first!
      log.message("Trying \(method.displayName)...", SSH_LOG_INFO)
      
      return method
        .auth(connection())
        .flatMap { result -> AnyPublisher<SSHClient, Error> in
          switch result {
          case .success:
            return .just(self)
          case .partial:
            return tryAuth(self.validAuthMethods(), tried: tried)
          default:
            var tried = tried
            var methods = methods
            
            if methods[0].name() == "none" {
              // Once we have tried, go for the rest.
              return tryAuth(self.validAuthMethods(), tried: tried)
            }
            
            if methods.count == 1 {
              tried.append(methods.removeFirst())
              
              // Return a failure and close the connection that's still open
              return .fail(error: SSHError.authFailed(methods: tried))
            }
            
            tried.append(methods.removeFirst())
            return tryAuth(methods, tried: tried)
          }
        }
        .eraseToAnyPublisher()
    }
    
    log.message("Authenticating...", SSH_LOG_INFO)
    return tryAuth([AuthNone()], tried: [])
  }
  
  public func requestInteractiveShell(withPTY pty: PTY? = PTY(),
                                      withEnvVars vars: [String: String] = [:]) -> AnyPublisher<Stream, Error> {
    return newChannel()
      .tryChannel { channel in
        self.log.message("SHELL Opening channel", SSH_LOG_INFO)
        let rc = ssh_channel_open_session(channel)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: self.session)
        }
        return channel
      }
      .tryChannel { channel in
        guard let pty = pty else {
          return channel
        }
        self.log.message("SHELL Request PTY", SSH_LOG_INFO)
        
        let rc = ssh_channel_request_pty_size(channel,
                                              pty.emulator,
                                              pty.columns, pty.rows)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: self.session)
        }
        return channel
      }
      .flatMap { self.requestEnvVars(channel: $0, vars: vars) }.eraseToAnyPublisher()
      .tryChannel { channel in
        self.log.message("SHELL Start", SSH_LOG_INFO)
        
        let rc = ssh_channel_request_shell(channel)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: self.session)
        }
        return Stream(channel, on: self)
      }
      .eraseToAnyPublisher()
  }
  
  public func requestSFTP() -> AnyPublisher<SFTPClient, Error> {
    var sftp: SFTPClient?
    self.log.message("SFTP Requested", SSH_LOG_INFO)
    
    return newChannel() // Upstream
      .tryChannel { channel -> ssh_channel in
        self.log.message("SFTP Starting Session", SSH_LOG_INFO)
        
        let rc = ssh_channel_open_session(channel)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: self.session)
        }
        
        guard let client = SFTPClient(on: channel, client: self) else {
          throw SSHError(title: "Could not allocate SFTP session")
        }
        
        sftp = client
        return channel
      }.tryChannel { channel -> ssh_channel in
        self.log.message("SFTP Starting Request SFTP", SSH_LOG_INFO)
        
        let rc = ssh_channel_request_sftp(channel)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: self.session)
        }
        
        return channel
      }.tryChannel { channel -> SFTPClient in
        self.log.message("SFTP Start", SSH_LOG_INFO)

        guard let sftp = sftp else {
          // This should never happen. But Combine...
          throw SSHError(title: "Does not have SFTP session")
        }

        // SFTP implementation needs to poll, except for files
        ssh_channel_set_blocking(channel, 1)
        try sftp.start()

        return sftp
      }
      .eraseToAnyPublisher()
  }
  
  public func requestExec(command cmd: String,
                          withPTY pty: PTY? = nil,
                          withEnvVars vars: [String: String] = [:]) -> AnyPublisher<Stream, Error> {
    log.message("Executing on remote: \(cmd)", SSH_LOG_INFO)
    return newChannel()
      .tryChannel { channel in
        self.log.message("EXEC Opening channel", SSH_LOG_INFO)
        let rc = ssh_channel_open_session(channel)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: self.session)
        }
        return channel
      }
      .tryChannel { channel in
        guard let pty = pty else {
          return channel
        }
        let rc = ssh_channel_request_pty_size(channel,
                                              pty.emulator,
                                              pty.columns, pty.rows)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: self.session)
        }
        return channel
      }
      .flatMap { self.requestEnvVars(channel: $0, vars: vars) }.eraseToAnyPublisher()
      .tryChannel { channel in
        self.log.message("EXEC Requesting on channel", SSH_LOG_INFO)
        let rc = ssh_channel_request_exec(channel, cmd)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: self.session)
        }
        return Stream(channel, on: self)
      }
  }
  
  // This just returns a listener setup in a way that will start the
  // proper forwarded channel whenever there is a request on it.
  public func requestForward(to endpoint: String, port: Int32, from host: String, localPort: Int32) -> AnyPublisher<Stream, Error> {
    self.log.message("Forward requested to address \(endpoint) on port \(port)", SSH_LOG_INFO)
    return newChannel()
      .tryChannel { channel in
        self.log.message("FORWARD Fulfill opening request", SSH_LOG_INFO)
        
        let rc = ssh_channel_open_forward(channel, endpoint, port, host, localPort)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: self.session)
        }
        
        // The stream does not pass information on "written" or "read". But it can be stopped.
        return Stream(channel, on: self)
      }
  }
  
  public func requestReverseForward(bindTo address: String?, port: Int32) -> AnyPublisher<Stream, Error> {
    if let _ = self.reversePorts[port] {
      return .fail(error: SSHError(title: "Reverse forward already exits for that port."))
    }
    
    self.log.message("REVERSE Forward requested to address \(address) on port \(port)", SSH_LOG_INFO)
    
    let cb: ssh_channel_open_request_forward_callback = { (session, port, userdata) in
      let ctxt = Unmanaged<SSHClient>.fromOpaque(userdata!).takeUnretainedValue()
      
      ctxt.log.message("REVERSE Forward callback", SSH_LOG_INFO)
      
      let port = Int32(port)

      // If there is no associated port, check if it may be on 0
      if ctxt.reversePorts[port] == nil {
        if let _ = ctxt.reversePorts[0] {
          ctxt.reversePorts[port] = ctxt.reversePorts.removeValue(forKey: 0)
        }
      }
      
      guard let pub = ctxt.reversePorts[port] else {
        return nil
      }
      
      guard let channel = ssh_channel_new(ctxt.session) else {
        return nil
      }
      ssh_channel_set_blocking(channel, 0)
      
      let stream = Stream(channel, on: ctxt)
      pub.send(stream)
      
      return channel
    }
    
    return connection()
      .tryOperation { session -> Int32 in
        self.log.message("REVERSE Starting listener to forward on remote", SSH_LOG_INFO)
        
        // We could pass the callback here, and then have somewhere on the libssh side a way to map
        let rc = ssh_channel_listen_forward(session, address, port, nil)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: session)
        }
        
        if self.callbacks.channel_open_request_forward_function == nil {
          self.callbacks.channel_open_request_forward_function = cb
          ssh_set_callbacks(session, &self.callbacks)
        }
        
        return port
      }.flatMap { port -> PassthroughSubject<Stream, Error> in
        let pub = PassthroughSubject<Stream, Error>()
        self.reversePorts[port] = pub
        
        return pub
      }.eraseToAnyPublisher()
  }
  
  func requestEnvVars(channel: ssh_channel, vars: [String:String] = [:]) -> AnyPublisher<ssh_channel, Error> {
    return vars.enumerated().publisher
      .flatMap { (_, arg1) -> AnyPublisher<ssh_channel, Error> in
        let (key, value) = arg1
        return AnyPublisher.just(channel)
          .tryChannel { channel in
            self.log.message("Requesting Env Var \(key)", SSH_LOG_INFO)
            let rc = ssh_channel_request_env(channel, key, value)
            if rc == SSH_AGAIN {
              throw SSHError(rc, forSession: self.session)
            } else if rc == SSH_ERROR {
              self.log.message("Error requesting Env Var \(key)", SSH_LOG_INFO)
            }
            return channel
          }
      }.reduce(channel) { $1 }.eraseToAnyPublisher()
  }
  
  func closeChannel(_ channel: ssh_channel) {
    self.rloop.perform {
      // Keep self so the Session is always deinited after the channels are closed.
      let _ = self
      self.log.message("Closing channel", SSH_LOG_INFO)
      ssh_channel_free(channel)
    }
  }
  
  deinit {
    self.log.message("Session deinit", SSH_LOG_INFO)
    ssh_free(session)
  }
}

public typealias SSHLoggerPublisher = PassthroughSubject<String, Never>
//typealias SSHLoggerMessage = (message: String, level: Int32)
public enum SSHLogLevel: Int {
  case none = 0
  case warn
  case info
  case debug
  case trace
}

class SSHLogger {
  let verbosity: SSHLogLevel
  let logger: SSHLoggerPublisher?
  
  init(verbosity level: SSHLogLevel, logger: PassthroughSubject<String, Never>?) {
    self.verbosity = level
    self.logger = logger
  }
  
  func message(_ message: String, _ level: Int32) {
    if verbosity.rawValue >= level {
      print(message)
      logger?.send(message)
    }
  }
}
