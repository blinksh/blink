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
import AppIntents

struct HostQuery: EntityQuery {
  func entities(for identifiers: [HostEntity.ID]) async throws -> [HostEntity] {
    []
//    guard let hosts = BKHosts.allHosts() else {
//      return []
//    }
//    return hosts.filter { h in
//      identifiers.contains(h.host ?? "")
//    }.map { h in
//      HostEntity(id: h.host ?? "")
//    }
  }
}

struct HostEntity: AppEntity, Identifiable {
  static var defaultQuery: HostQuery = HostQuery()

//  typealias DefaultQuery = HostQuery

  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    .init(stringLiteral: "Host")
  }

  var displayRepresentation: DisplayRepresentation {
    .init(title: "\(id)")
  }

  var id: String
}

//@available(iOS 16, *)
struct WolIntent: AppIntent {
//  typealias PerformResult = <#type#>
  
//  typealias SummaryContent = LocalizedStringResource(stringLiteral: "Wake on Lan \(.host)")
  
//  static var parameterSummary: SummaryContent {
//    IntentParameterSummary("Wake \(\.$host)")
//  }
  
  @Parameter(title: "Host")
  var host: HostEntity
  
  func perform() async throws -> some IntentResult {
    print("Wake On Lan")
    return .result()
  }
  
  static var title: LocalizedStringResource {
    LocalizedStringResource(stringLiteral: "Wake on Lan")
  }
}

//@available(iOS 16, *)
public struct AutoShortcuts: AppShortcutsProvider {
  public static var appShortcuts: [AppShortcut] {
    AppShortcut (
      intent: WolIntent(),
      phrases: ["3 Wake On Lan \(.applicationName)"],
      systemImageName:"zzz"
    )
  }
}
