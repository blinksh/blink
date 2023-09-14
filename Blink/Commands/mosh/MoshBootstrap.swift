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

import BlinkFiles
import SSH

// We have decided to hard-code the version of Blink so client-server match.
let MoshServerBinaryName  = "mosh-server"
let MoshServerVersion     = "1.32.0"
let MoshServerDownloadURL = URL(string: "https://github.com/dtinth/mosh-static/releases/latest/download/\(MoshServerBinaryName)-\(MoshServerVersion)")!

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

protocol MoshBootstrap {
  func start(on client: SSHClient) -> AnyPublisher<String, Error>
}

// NOTE We could enforce "which" on interactive shell, but that is not standard mosh bootstrap.
class UseMoshOnPath: MoshBootstrap {
  let path: String

  init(path: String? = nil) {
    self.path = path ?? MoshServerBinaryName
  }

  func start(on client: SSHClient) -> AnyPublisher<String, Error> {
    Just(self.path).setFailureType(to: Error.self).eraseToAnyPublisher()
  }
}

class UseStaticMosh: MoshBootstrap {
  let blinkRemoteLocation: String

  init() {
    // TODO We could also read this from env variable.
    self.blinkRemoteLocation = "~/.blink/"
  }

  func start(on client: SSHClient) -> AnyPublisher<String, Error> {
    Just(())
      .flatMap { self.platformAndArchitecture(on: client) }
      .tryMap { pa in
        guard let platform = pa?.0,
              let architecture = pa?.1 else {
          throw MoshError.NoBinaryAvailable
        }

        return (platform, architecture)
      }
      .flatMap { self.getMoshServerBinary(platform: $0, architecture: $1) }
      .flatMap { self.installMoshServerBinary(on: client, localMoshServerBinary: $0) }
      .print()
      .eraseToAnyPublisher()
  }

  private func platformAndArchitecture(on client: SSHClient) -> AnyPublisher<(Platform, Architecture)?, Error> {
    client.requestExec(command: "uname && uname -m")
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

  private func getMoshServerBinary(platform: Platform, architecture: Architecture) -> AnyPublisher<Translator, Error> {
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

  private func installMoshServerBinary(on client: SSHClient, localMoshServerBinary: Translator) -> AnyPublisher<String, Error> {
    // TODO Try to use .local
    let RemoteBlinkLocation = ".blink"

    return client.requestSFTP()
      .tryMap { try SFTPTranslator(on: $0) }
      .flatMap { sftp in
        // TODO We may still need the mosh-server link if we use a prompt.
        // Ie. On update, names won't match, but we may not want to prompt the user again if we
        // previously installed.
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
