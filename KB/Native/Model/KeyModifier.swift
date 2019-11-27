//
//  KeyModifier.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

enum KeyModifier: String, Codable {
  case none       = ""
  case escape     = "Escape"
  case bit8       = "8-bit"
  case shift      = "Shift"
  case control    = "Control"
  case meta       = "Meta"
  case metaEscape = "Meta-Escape"
  
  var description: String {
    switch self {
    case .none:       return ""
    case .escape:     return "Escape"
    case .bit8:       return "8-bit"
    case .shift:      return "Shift"
    case .control:    return "Control"
    case .meta:       return "Meta"
    case .metaEscape: return "Meta Escape"
    }
  }
  
}
