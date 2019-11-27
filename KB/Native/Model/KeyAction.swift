//
//  KeyAction.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

enum KeyAction: String, Codable {
  case none       = ""
  case escape     = "escape"
  case ctrlSpace  = "ctrl+space"
  case tab        = "tab"
  
  var description: String {
    switch self {
    case .none:      return ""
    case .escape:    return "⎋"
    case .ctrlSpace: return "⌃␣"
    case .tab:       return "⇥"
    }
  }
}
