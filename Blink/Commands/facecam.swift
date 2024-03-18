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
import ArgumentParser
import AVFoundation

import ios_system


struct FaceCam: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "facecam",
    abstract: "Show facecam on the screen",
    subcommands: [On.self, Off.self],
    defaultSubcommand: On.self
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standard
  
  struct On: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Turn on facecam",
      discussion: "Scale, move, and double tap to mirror..."
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standard
    
    func run() throws {
      var sema: DispatchSemaphore? = nil
      
      printDebug("Checking authorization status")
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .notDetermined:
        printDebug("Status is not determined. Requesting access...")
        sema = .init(value: 1)
        var accessGranted = false
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
          accessGranted = granted
          sema?.signal()
        })
        sema?.wait()
        if accessGranted {
          printDebug("Access granted.")
          print("Just smile and wave...")
        } else {
          printDebug("Access not granted.")
        }
        
      case .restricted:
        printDebug("Access is restricted")
        print("Warning: Please grant Camera access to Blink.app in Settings.app.")
      case .denied:
        printDebug("Access is denied")
        print("Warning: Please grant Camera access to Blink.app in Settings.app")
      case .authorized:
        printDebug("Status is authorized")
        print("Just smile and wave...")
      @unknown default: break
      }
      
      let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
      DispatchQueue.main.async {
        if let spcCtrl = session.device.view.window?.rootViewController as? SpaceController {
          if #available(iOS 16.0, *) {            
            #if targetEnvironment(macCatalyst)
            var multitaskCameraAccessSupported = false;
            #else
            var multitaskCameraAccessSupported = AVCaptureSession().isMultitaskingCameraAccessSupported
            #endif
            
            if multitaskCameraAccessSupported {
              PipFaceCamManager.attach(spaceCtrl: spcCtrl)
            } else {
              FaceCamManager.attach(spaceCtrl: spcCtrl)
            }
          } else {
            FaceCamManager.attach(spaceCtrl: spcCtrl)
          }
        }
      }
      
    }
  }
  
  struct Off: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Turn off facecam"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standard
    
    func run() throws {
      print("See you next time!")
      DispatchQueue.main.async {
        FaceCamManager.turnOff()
        PipFaceCamManager.turnOff()
      }
    }
  }
}

@_cdecl("facecam_main")
public func facecam_main(argc: Int32, argv: Argv) -> Int32 {
  setvbuf(thread_stdin, nil, _IONBF, 0)
  setvbuf(thread_stdout, nil, _IONBF, 0)
  setvbuf(thread_stderr, nil, _IONBF, 0)

  let io = NonStdIO.standard
  io.out = OutputStream(file: thread_stdout)
  io.err = OutputStream(file: thread_stderr)
  
  return FaceCam.main(Array(argv.args(count: argc)[1...]), io: io)
}
