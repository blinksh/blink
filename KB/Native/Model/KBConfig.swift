//
//  KBConfig.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import Combine

class KBConfig: ObservableObject, Codable {
  let capsLock: KeyConfig
  let shift:    KeyConfigPair
  let control:  KeyConfigPair
  let option:   KeyConfigPair
  let command:  KeyConfigPair
  
  init(
    capsLock: KeyConfig     = .capsLock,
    shift:    KeyConfigPair = .shift,
    control:  KeyConfigPair = .control,
    option:   KeyConfigPair = .option,
    command:  KeyConfigPair = .command
  ) {
    self.capsLock = capsLock
    self.shift    = shift
    self.control  = control
    self.option   = option
    self.command  = command
  }
  
  // - MARK: Codable
  
  enum Keys: CodingKey {
    case capsLock
    case shift
    case control
    case option
    case command
  }
  
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    try c.encode(capsLock, forKey: .capsLock)
    try c.encode(shift,    forKey: .shift)
    try c.encode(control,  forKey: .control)
    try c.encode(option,   forKey: .option)
    try c.encode(command,  forKey: .command)
  }
  
  required convenience init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    
    let capsLock = try c.decode(KeyConfig.self,     forKey: .capsLock)
    let shift    = try c.decode(KeyConfigPair.self, forKey: .shift)
    let control  = try c.decode(KeyConfigPair.self, forKey: .control)
    let option   = try c.decode(KeyConfigPair.self, forKey: .option)
    let command  = try c.decode(KeyConfigPair.self, forKey: .command)
    
    self.init(capsLock: capsLock, shift: shift, control: control, option: option, command: command)
  }
}
