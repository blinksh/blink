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
import CryptoKit

import BlinkFiles
import SSH

// We have decided to hard-code the version of Blink so client-server match.
// Static and override with env variable.
let MoshServerRemotePath = ".local/blink"
let MoshServerBinaryName  = "mosh-server"
let MoshServerVersion     = "1.4.0"
let MoshServerDownloadPathURL = URL(string: "https://github.com/blinksh/mosh-static-multiarch/releases/latest/download/")!
// TODO
fileprivate enum Checksum {
  static let DarwinArm64 = "24df62e8f1490f5dc58a8ae50ae39957d5bf80d57f5f07fa81d46199b890dfd3"
  static let DarwinX86_64 = "f4b7ed42a54d0ea743a157179eb0aaa9e30d2e67b869217c158f331ae396f317"
  static let LinuxAmd64 = "e7aa244fbd0466273ae2ad34f3c26ba7b660438ee8635d7180950e255384b906"
  static let LinuxArm64 = "9a2b5cc731664eb18f46a9aa14886c341b21d2f08ca798b6ea8c4e61313489e0"
  static let LinuxArmv7 = "930aa3b4a40bf67fa56a17cfc3ba119cc7fa0f0bbd1760562ef0f9cefbc0466e"
  static func validate(data: Data, platform: Platform, architecture: Architecture) -> Bool {
    let hash = SHA256.hash(data: data)
    let hexHash = hash.map { byte in  String(format: "%02x", byte)}.joined()
    let checksum: String
    switch (platform, architecture) {
    case (.Darwin, .X86_64):
      checksum = Self.DarwinX86_64
    case (.Darwin, .Arm64):
      checksum = Self.DarwinArm64
    case (.Linux, .Amd64):
      checksum = Self.LinuxAmd64
    case (.Linux, .Arm64):
      checksum = Self.LinuxArm64
    case (.Linux, .Armv7):
      checksum = Self.LinuxArmv7
    case (.Linux, .X86_64):
      checksum = Self.LinuxAmd64
    default:
      return false
    }
    return checksum == hexHash
  }
}

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

extension Platform: CustomStringConvertible {
  public var description: String { 
    switch self {
    case .Darwin:
      return "darwin"
    case .Linux:
      return "linux"
    }
  }
}

enum Architecture {
  case X86_64
  case Amd64
  case Aarch64
  case Arm64
  case Armv7
}

extension Architecture {
  init?(from str: String) {
    switch str.lowercased() {
    case "x86_64":
      self = .X86_64
    case "aarch64":
      self = .Arm64
    case "arm64":
      self = .Arm64
    case "amd64":
      self = .Amd64
    case "armv7":
      self = .Armv7
    case "armv7l":
      self = .Armv7
    default:
      return nil
    }
  }
}

extension Architecture {
  public var downloadableDescription: String {
    switch self {
    case .X86_64:
      return "amd64"
    case .Aarch64:
      return "arm64"
    case .Arm64:
      return "arm64"
    case .Amd64:
      return "amd64"
    case .Armv7:
      return "armv7"
    }
  }
}

protocol MoshBootstrap {
  func start(on client: SSHClient) -> AnyPublisher<String, Error>
}

// NOTE We could enforce "which" on interactive shell as a different bootstrap method.
class UseMoshOnPath: MoshBootstrap {
  let path: String

  init(path: String? = nil) {
    self.path = path ?? MoshServerBinaryName
  }
  
  static func staticMosh() -> UseMoshOnPath {
    UseMoshOnPath(path: "~/\(MoshServerRemotePath)/\(MoshServerBinaryName)")
  }

  func start(on client: SSHClient) -> AnyPublisher<String, Error> {
    Just(self.path).setFailureType(to: Error.self).eraseToAnyPublisher()
  }
}

class InstallStaticMosh: MoshBootstrap {
  let promptUser: Bool
  let onCancel: () -> ()
  let logger: MoshLogger

  init(promptUser: Bool = true, onCancel: @escaping () -> () = {}, logger: MoshLogger) {
    self.promptUser = promptUser
    self.onCancel = onCancel
    self.logger = logger
  }

  func start(on client: SSHClient) -> AnyPublisher<String, Error> {
    let log = logger.log("InstallStaticMosh")
    let prompt = InstallStaticMoshPrompt()
    
    return Just(())
      .flatMap { [unowned self] in self.platformAndArchitecture(on: client) }
      .tryMap { pa in
        guard let platform = pa?.0,
              let architecture = pa?.1 else {
          throw MoshError.NoBinaryAvailable
        }

        if !self.promptUser || prompt.installMoshRequest() {
          return (platform, architecture)
        } else {
          throw MoshError.UserCancelled
        }
      }
      .flatMap { [unowned self] in self.getMoshServerBinary(platform: $0, architecture: $1) }
      .flatMap { [unowned self] in self.installMoshServerBinary(on: client, localMoshServerBinary: $0) }
      .print()
      .eraseToAnyPublisher()
  }

  private func platformAndArchitecture(on client: SSHClient) -> AnyPublisher<(Platform, Architecture)?, Error> {
    let log = logger.log("platformAndArchitecture")
    
    return client.requestExec(command: "uname && uname -m")
      .flatMap { s -> AnyPublisher<DispatchData, Error> in
        s.read(max: 1024)
      }
      .map { String(decoding: $0 as AnyObject as! Data, as: UTF8.self).components(separatedBy: .newlines) }
      .map { lines -> (Platform, Architecture)? in
        log.info("uname output: \(lines)")
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

  func getMoshServerBinary(platform: Platform, architecture: Architecture) -> AnyPublisher<Translator, Error> {
    let moshServerReleaseName = "\(MoshServerBinaryName)-\(MoshServerVersion)-\(platform)-\(architecture.downloadableDescription)"
    let localMoshServerURL = BlinkPaths.blinkURL().appending(path: moshServerReleaseName)
    let moshServerDownloadURL = MoshServerDownloadPathURL.appending(path: moshServerReleaseName)
    let log = logger.log("getMoshServerBinary")
    let prompt = InstallStaticMoshPrompt()
    
    log.info("\(platform) \(architecture.downloadableDescription)")
    return Local().cloneWalkTo(localMoshServerURL.path)
      .catch { _ in
        log.info("Downloading \(moshServerDownloadURL)")
        prompt.showDownloadProgress(cancellationHandler: { [weak self] in self?.onCancel() })
        return URLSession.shared.dataTaskPublisher(for: moshServerDownloadURL)
          .map(\.data)
          .tryMap { data in
            guard Checksum.validate(data: data, platform: platform, architecture: architecture) else {
              log.error("Download mismatch. Downloaded size: \(data.count)")
              throw MoshError.NoChecksumMatch
            }
            try data.write(to: localMoshServerURL)
            prompt.progressUpdate(1.0)
            return localMoshServerURL
          }
          .flatMap {
            Local().cloneWalkTo($0.path)
          }
      }.eraseToAnyPublisher()
  }

  private func installMoshServerBinary(on client: SSHClient, localMoshServerBinary: Translator) -> AnyPublisher<String, Error> {
    let moshServerRemotePath = NSString(string: MoshServerRemotePath)
    let moshServerBinaryPath = moshServerRemotePath.appendingPathComponent(MoshServerBinaryName)
    let log = logger.log("installMoshServerBinary")
    let prompt = InstallStaticMoshPrompt()
    
    log.info("on \(moshServerBinaryPath)")
    var uploaded: UInt64 = 0
    return client.requestSFTP()
      .tryMap { try SFTPTranslator(on: $0) }
      .flatMap { sftp in
        sftp.cloneWalkTo(moshServerBinaryPath)
          .catch { _ in
            prompt.showUploadProgress(cancellationHandler: { [weak self] in self?.onCancel() })
            return sftp.cloneWalkTo(moshServerRemotePath.standardizingPath)
              .catch { _ in
                log.info("Path not found: \(moshServerRemotePath.standardizingPath). Creating it...")
                return sftp.mkPath(path: moshServerRemotePath.standardizingPath)
              }
              // Upload file
              .flatMap { dest in
                dest.copy(from: [localMoshServerBinary])
                  .tryMap { info in
                    uploaded += info.written
                    let percentage = Float(uploaded) / Float(info.size)
                    // Tested. If something happens, it closes properly.
                    // if percentage > 0.5 { throw MoshError.UserCancelled }
                    prompt.progressUpdate(percentage)
                  }
              }
              .last()
              .flatMap { _ -> AnyPublisher<Translator, Error> in
                let uploadedBinaryPath = moshServerRemotePath
                  .appendingPathComponent((localMoshServerBinary.current as NSString).lastPathComponent)
                log.info("File uploaded at \(uploadedBinaryPath). Moving to \(moshServerBinaryPath)")

                return sftp.cloneWalkTo(uploadedBinaryPath)
                  .flatMap { $0.wstat([.name: MoshServerBinaryName]) }
                  .flatMap { _ in sftp.cloneWalkTo(moshServerBinaryPath) }
                  .eraseToAnyPublisher()
              }
          }
          .map { $0.current }
          // Set execution flag.
          .flatMap { moshPath in
            let command = "chmod +x \(moshPath)"
            log.info("chmod +x \(moshPath)")
            return client.requestExec(command: command)
              .flatMap { $0.read_err(max: 1024) }
              .tryMap { err_out in
                prompt.progressUpdate(1.0)
                if err_out.count > 0 {
                  log.error("chmod err: \(err_out)")
                  throw MoshError.NoBinaryExecFlag
                } else { return moshPath }
              }
          }
      }
      .eraseToAnyPublisher()
  }
  
  deinit {
    print("Install Mosh OUT")
  }
}

class InstallStaticMoshPrompt {
  public var name: String { "User Prompt" }
  var window: UIWindow? = nil
  var progressView: UIProgressView? = nil

  public func installMoshRequest() -> Bool {
    var shouldInstall = false
    let semaphore = DispatchSemaphore(value: 0)
    
    let alert = UIAlertController(title: "Mosh server not found", message: "Blink will try to install mosh on the remote.", preferredStyle: .alert)
    
    alert.addAction(
      UIAlertAction(title: NSLocalizedString("Continue", comment: "Install"),
                    style: .default,
                    handler: { _ in
                      shouldInstall = true
                      semaphore.signal()
                      self.window = nil
                    }))
    alert.addAction(
      UIAlertAction(title: NSLocalizedString("Cancel", comment: "Do not install"),
                    style: .cancel,
                    handler: { _ in
                      shouldInstall = false
                      semaphore.signal()
                      self.window = nil
                    }))

    self.displayAlert(alert, completion: nil)

    semaphore.wait()

    return shouldInstall
  }
  
  public func showDownloadProgress(cancellationHandler: @escaping () -> ()) {
    // Show download progress. Communicate progress. Once done, dismiss.
    let alert = UIAlertController(title: "Downloading mosh-server to device", message: "", preferredStyle: .alert)
    
    alert.addAction(
      UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel the download"),
                    style: .cancel,
                    handler: { [weak self] _ in
                      cancellationHandler()
                      self?.window = nil
                    }))
    
    self.displayAlert(alert, completion: nil)
  }
  
  public func showUploadProgress(cancellationHandler: @escaping () -> ()) {
    let alert = UIAlertController(title: "Uploading mosh-server to remote", message: "", preferredStyle: .alert)
    
    alert.addAction(
      UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel the upload"),
                    style: .cancel,
                    handler: { [weak self] _ in
                      cancellationHandler()
                      self?.window = nil
                      self?.progressView = nil
                    }))
    
    self.displayAlert(alert, completion: {
      let margin:CGFloat = 8.0
      let rect = CGRect(x: margin, y: 72.0, width: alert.view.frame.width - margin * 2.0 , height: 2.0)
      self.progressView = UIProgressView(frame: rect)
      self.progressView!.tintColor = self.window?.tintColor
      alert.view.addSubview(self.progressView!)
    })
  }

  // Kinda like the DownloadDelegate for the URLSession. But we don't need to reuse this.
  public func progressUpdate(_ progress: Float) {
    if progress == 1.0 {
      self.progressView = nil
      self.window = nil
    } else {
      DispatchQueue.main.async {
        self.progressView?.progress = progress
      }
    }
  }
  
  private func displayAlert(_ alert: UIAlertController, completion: (() -> ())?) {
    DispatchQueue.main.async {
      let foregroundActiveScene = UIApplication.shared.connectedScenes.filter { $0.activationState == .foregroundActive }.first
      guard let foregroundWindowScene = foregroundActiveScene as? UIWindowScene else {
        // semaphore.signal()
        return
      }
      
      let window = UIWindow(windowScene: foregroundWindowScene)
      self.window = window
      window.rootViewController = UIViewController()
      window.windowLevel = .alert + 1
      window.makeKeyAndVisible()
      window.rootViewController!.present(alert, animated: true, completion: completion)
    }
  }
}
