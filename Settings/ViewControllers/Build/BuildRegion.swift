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
import SwiftUI

enum BuildRegion: String {
  case USEast1 = "us_east1"
  case USWest1 = "us_west1"
  case Equrope1 = "europe1"
  
  case USEast0 = "us_east0"
  case Europe0 = "europe0"
  
  case Test = "test_region"
}

extension BuildRegion {
  @ViewBuilder
  func full_title_label() -> some View {
    Label(self.full_title(), systemImage: systemImage())
  }
  
  static func all() -> [BuildRegion] {
    [
      .USEast1,
      .USWest1,
      .Equrope1,
      .USEast0,
      .Europe0,
      .Test,
    ]
  }
  
  func title() -> String {
    switch self {
    case .USEast1: return "US East"
    case .USWest1: return "US West"
    case .Equrope1: return "Europe"
      
    case .Europe0: return "Europe0"
    case .USEast0: return "US East0"
      
    case .Test: return "Test"
    }
  }
  
  func full_title() -> String {
    switch self {
    case .USEast1: return "US East Region"
    case .USWest1: return "US West Region"
    case .Equrope1: return "Europe Region"
      
    case .Europe0: return "Europe Staging Region"
    case .USEast0: return "US East Staging Region"
      
    case .Test: return "Test Region"
    }
  }
  
  func systemImage() -> String {
    switch self {
    case .USEast1: return "globe.americas.fill"
    case .USWest1: return "globe.americas.fill"
    case .Equrope1: return "globe.europe.africa.fill"
      
    case .Europe0: return "globe.europe.africa"
    case .USEast0: return "globe.americas"
      
    case .Test: return  "globe.desk"
    }
  }
}


