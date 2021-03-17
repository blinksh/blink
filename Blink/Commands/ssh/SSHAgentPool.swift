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

import SSH


public let DefaultAgentName = "default"

final class SSHAgentPool {
  private static let shared = SSHAgentPool()
  public static let defaultAgent = SSHAgentPool.shared.agent(DefaultAgentName)
  
  private var agents: [String:SSHAgent] = [:]
  
  private init() {}
  
  func agent(_ name: String) -> SSHAgent {
    if let agent = agents[name] {
      return agent
    } else {
      let agent = SSHAgent()
      agents[name] = agent
      return agent
    }
  }
  
  static func get(agent name: String = DefaultAgentName) -> SSHAgent? {
    return Self.shared.agents[name]
  }
  
  static func addKey(_ key: Signer, named keyName: String, constraints: [SSHAgentConstraint]? = nil, toAgent agentName: String = DefaultAgentName) {
    let agent = Self.shared.agent(agentName)    
    agent.loadKey(key, aka: keyName, constraints: constraints)
  }
  
  static func removeKey(named keyName: String, fromAgent agentName: String = DefaultAgentName) -> Signer? {
    guard let agent = Self.shared.agents[agentName] else {
      return nil
    }
    
    return agent.removeKey(keyName)
  }
}
