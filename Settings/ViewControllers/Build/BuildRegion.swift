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
  case usEast1 = "us_east1"
  case usWest1 = "us_west1"
  case europe1 = "europe1"
  
  case usEast0 = "us_east0"
  case europe0 = "europe0"
  
  case test = "test_region"
}

extension BuildRegion: Identifiable {
  var id: String { self.rawValue }
}

extension BuildRegion {
  var location: String {
    switch self {
    case .usEast0: return "New York City" // nyc1
    case .usEast1: return "New York City" // nyc3
    case .usWest1: return "San Francisco" // sfo1
      
    case .europe0: return "Amsterdam, the Netherlands" // ams3
    case .europe1: return "Frankfurt, Germany" // fra1
    case .test: return "London, UK" // lon1
    }
  }
}

extension BuildRegion {
  
  @ViewBuilder
  func fullTitleLabel() -> some View {
    Label(self.fullTitle(), systemImage: systemImage())
  }
  
  @ViewBuilder
  func largeTitleLabel() -> some View {
    Label(title: {
      HStack {
        Text(self.title())
        Text(self.location).foregroundColor(.secondary)
      }
    }, icon: {
      Image(systemName: systemImage())
    })
  }
  
  static func envAvailable() -> [BuildRegion] {
    if FeatureFlags.blinkBuildStaging {
      return all()
    } else {
      return productionAvailable()
    }
  }
  
  static func productionAvailable() -> [BuildRegion] {
    [
      .usEast1,
      .usWest1,
      .europe1,
    ]
  }
  
  static func all() -> [BuildRegion] {
    [
      .usEast1,
      .usWest1,
      .europe1,
      .usEast0,
      .europe0,
//      .test,
    ]
  }
  
  func title() -> String {
    switch self {
    case .usEast1: return "US East"
    case .usWest1: return "US West"
    case .europe1: return "Europe"
      
    case .europe0: return "Europe0"
    case .usEast0: return "US East0"
      
    case .test: return "Test"
    }
  }
  
  func fullTitle() -> String {
    switch self {
    case .usEast1: return "US East Region"
    case .usWest1: return "US West Region"
    case .europe1: return "Europe Region"
      
    case .europe0: return "Europe Staging Region"
    case .usEast0: return "US East Staging Region"
      
    case .test: return "Test Region"
    }
  }
  
  func systemImage() -> String {
    switch self {
    case .usEast1: return "globe.americas.fill"
    case .usWest1: return "globe.americas.fill"
    case .europe1: return "globe.europe.africa.fill"
      
    case .europe0: return "globe.europe.africa"
    case .usEast0: return "globe.americas"
      
    case .test: return  "globe.desk"
    }
  }
}


