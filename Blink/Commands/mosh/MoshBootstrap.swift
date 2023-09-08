import Combine

import BlinkFiles
import SSH

// We can test MoshBootstrap
// We could use different Strategies for bootstrap
// TODO Just for testing, this needs a version.
let MoshServerBinaryName = "mosh-server"
let MoshServerDownloadURL = URL(string: "https://github.com/dtinth/mosh-static/releases/latest/download/\(MoshServerBinaryName)")!

enum Platform {
  case Darwin
  case Linux
}

extension Platform {
  init?(from str: String) {
    switch str.lowercased() {
    case "darwin":
      self = .Darwin
    case "linux":
      self = .Linux
    default:
      return nil
    }
  }
}

enum Architecture {
  case X86_64
  case Arm64
}

extension Architecture {
  init?(from str: String) {
    switch str.lowercased() {
    case "x86_64":
      self = .X86_64
    case "arm64":
      self = .Arm64
    default:
      return nil
    }
  }
}

enum MoshBootstrapError: Error {
  case NoBinaryAvailable
}

struct MoshBootstrap {
  let client: SSHClient
  let blinkRemoteLocation: String

  
  init(client: SSHClient) {
    self.client = client
    // TODO We could also read this from env variable.
    self.blinkRemoteLocation = "~/.blink/"
  }

  // Return an AnyPublisher<MoshConnectionInfo, Error>
  func start() -> AnyPublisher<String, Never> {
    // Create SSH connection.
    // - We should be able to use the same client as SSH.
    // Check the version for mosh-server installed at .blink/mosh-server
    // - If we do it by checking version on file, we will have to delete and re-upload
    // Run mosh-server and capture

    // 1 - Figure out platform and architecture
    // This could be part of the SSH library, and we could use this from our side later.
    // Get the special publisher from Snips.
    
    return Just(())
      .flatMap { platformAndArchitecture() }
      .tryMap { pa in
        guard let platform = pa?.0,
              let architecture = pa?.1 else {
          throw MoshBootstrapError.NoBinaryAvailable
        }
        
        return (platform, architecture)
      }
      .flatMap { getMoshServer(platform: $0, architecture: $1) }
      .flatMap { installMoshServer(localMoshServerBinary: $0) }
    // Select binary. We separate as then we can return proper errors from just this function.
    // Check binary on remote (resolve link over sftp)
    // - Download and upload
    // Return binary location
      .print()
      .assertNoFailure()
      .eraseToAnyPublisher()
    // -> Below can be done by a separate flow. This way we reuse
    // We can also include a "which" mosh-server call in an alternative method.
    // Run binary on remote
    // Capture Mosh parameters

  }

  func platformAndArchitecture() -> AnyPublisher<(Platform, Architecture)?, Error> {
    self.client.requestExec(command: "uname && uname -m")
      .flatMap { s -> AnyPublisher<DispatchData, Error> in
        s.read(max: 1024)
      }
      .map { String(decoding: $0 as AnyObject as! Data, as: UTF8.self).components(separatedBy: .newlines) }
      .map { lines -> (Platform, Architecture)? in
        if lines.count != 3 {
          return nil
        }
        
        guard let platform = Platform(from: lines[0]),
              let architecture = Architecture(from: lines[1]) else {
          return nil
        }

        return (platform, architecture)
      }.eraseToAnyPublisher()
  }
  
  func getMoshServer(platform: Platform, architecture: Architecture) -> AnyPublisher<Translator, Error> {
    let localMoshServerURL = BlinkPaths.blinkURL().appending(path: MoshServerBinaryName)
    return URLSession.shared.dataTaskPublisher(for: MoshServerDownloadURL)
      .map(\.data)
      .tryMap { data in
        try data.write(to: localMoshServerURL)
        return localMoshServerURL
      }
      .flatMap {
        Local().cloneWalkTo($0.path)
      }
      .eraseToAnyPublisher()
  }
  
  // try to use .local
  func installMoshServer(localMoshServerBinary: Translator) -> AnyPublisher<String, Error> {
    let RemoteBlinkLocation = ".blink"

    return self.client.requestSFTP()
      .tryMap { try SFTPTranslator(on: $0) }
      .flatMap { sftp in
        // We may not need this check if we are hard-coding the version to Blink.
        // Unless we also want to clean things up.
        // A device if not updated can still install its version.
        sftp.cloneWalkTo("~/\(RemoteBlinkLocation)/\(MoshServerBinaryName)")
          .catch { _ in
            sftp.cloneWalkTo(RemoteBlinkLocation)
              .catch { _ in
                sftp.mkdir(name: RemoteBlinkLocation)
              }
              // Upload file
              .flatMap { dest in
                dest.copy(from: [localMoshServerBinary])
              }
              .last()
              .flatMap { _ in sftp.cloneWalkTo("~/\(RemoteBlinkLocation)/\(MoshServerBinaryName)") }
          }
          .map { $0.current }
      }
      .eraseToAnyPublisher()
      
  }
}
