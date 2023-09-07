import Combine

import SSH

// We can test MoshBootstrap
// We could use different Strategies for bootstrap

enum Platform {
  case Darwin
  case Linux
}

extension Platform {
  init?(from str: String) {
    switch str {
    case "Darwin":
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

struct MoshBootstrap {
  let client: SSHClient
  let blinkRemoteLocation: String

  init(client: SSHClient) {
    self.client = client
    // TODO We could also read this from env variable.
    self.blinkRemoteLocation = "~/.blink/"
  }

  // Return an AnyPublisher<MoshConnectionInfo, Error>
  func start() async {
    // Create SSH connection.
    // - We should be able to use the same client as SSH.
    // Check the version for mosh-server installed at .blink/mosh-server
    // - If we do it by checking version on file, we will have to delete and re-upload
    // Run mosh-server and capture

    // 1 - Figure out platform and architecture
    // This could be part of the SSH library, and we could use this from our side later.
    // Get the special publisher from Snips.

    // dialWithTestConfig -> SSHClient
    // Do we have any other way to convert to string directly?
    
    // This has the problem that the model is not cancellable.
    // They added Actors and a lot of other complexities for this, but not worth it.
    // https://stackoverflow.com/questions/71837201/task-blocks-main-thread-when-calling-async-function-inside
    let platform = await client
      .requestExec(command: "uname")
      .flatMap { s -> AnyPublisher<DispatchData, Error> in
        s.read(max: 1024)
      }
      .map { String(decoding: $0 as AnyObject as! Data, as: UTF8.self) }
      .map { Platform(from: $0) }
      .assertNoFailure()
      .values
      .first()
      
    guard let platform = platform else {
      print("no platform found")
      return
    }
    
    print("Platform is \(platform)")

    //await client.execute("").map { SystemArch(output.parse) }

    // client.sftp_client.map { $0.translator() }
    // 1 - List folder and search for mosh-server
    // 2 - Resolve from symlink. Test it, I'm not sure it will work.
    
  }

//  async func platformAndArchitecture() throws -> (Platform, Architecture) {
//    
//  }
}

// Could not find any implementation atm. But looks like it may be coming.
// https://forums.swift.org/t/concurrency-asyncsequence/42417
extension AsyncSequence {
  func first() async rethrows -> AsyncIterator.Element? {
    var iter = self.makeAsyncIterator()
    return try await iter.next()
  }
}
