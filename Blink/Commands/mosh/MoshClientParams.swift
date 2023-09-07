//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2023 Blink Mobile Shell Project
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

struct MoshClientParams {
  let predictionMode: BKMoshPrediction
  let predictOverwrite: String?
  let experimentalRemoteIP: BKMoshExperimentalIP
  let customUDPPort: String?
  let server: String
  let remoteExecCommand: String?

  init(extending cmd: MoshCommand) {
    let bkHost = BKHosts.withHost(cmd.hostAlias)

    let customUDPPort: String? = if let moshPort = bkHost?.moshPort { String(describing: moshPort) } else { nil }
    self.customUDPPort = cmd.customUDPPort ?? customUDPPort
    let moshServer: String? = if let moshServer = bkHost?.moshServer, !moshServer.isEmpty { moshServer } else { nil }
    self.server  = cmd.server ?? moshServer ?? "mosh-server"
    self.predictionMode = cmd.predict ?? BKMoshPrediction(UInt32(truncating: bkHost?.prediction ?? 0))
    self.predictOverwrite = cmd.predictOverwrite ? "yes" : bkHost?.moshPredictOverwrite
    self.experimentalRemoteIP = cmd.experimentalRemoteIP ?? BKMoshExperimentalIP(UInt32(truncating: bkHost?.moshExperimentalIP ?? 0))
    let remoteExecCommand: String? = if let command = bkHost?.moshStartup, !command.isEmpty { command } else { nil }
    self.remoteExecCommand = !cmd.remoteExecCommand.isEmpty ? cmd.remoteExecCommand.joined(separator: " ") : remoteExecCommand
  }
}
