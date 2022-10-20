////////////////////////////////////////////////////////////////////////////////
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
import BlinkConfig

extension URLCache {
    static let imageCache = URLCache(memoryCapacity: 512*1000*1000, diskCapacity: 10*1000*1000*1000)
}


protocol RowsProvider: ObservableObject {
    var rows: [WhatsNewRow] { get }
    var hasFetchedData: Bool { get }

    func fetchData() async throws
}

class RowsViewModel: RowsProvider {
    @Published var rows = [WhatsNewRow]()
    @Published var hasFetchedData = false
    @Published var error: Error?
    private let url = URL(string: XCConfig.infoPlistWhatsNewURL())!

    @MainActor
    func fetchData() async throws {
      let (data, _) = try await URLSession.shared.data(from: url)
      let decoder = JSONDecoder()
      rows = try decoder.decode([WhatsNewRow].self, from: data)
      hasFetchedData = true
    }
}

let RowSamples = [
  WhatsNewRow.oneCol(
    Feature(title: "Your terminal, your way", description: "You can rock your own terminal and roll your own themes beyond our included ones.", image: URL(string: "https://blink-363718.web.app/whatsnew/test.png")!, color: .blue, symbol: "globe", link: URL(string: "http://blink.sh"))
  ),
  WhatsNewRow.versionInfo(VersionInfo(number: "1.0.0", link: URL(string:"http://blink.sh"))),
    WhatsNewRow.twoCol(
      [Feature(title: "Passkeys", description: "Cool keys on your phone.", image: URL(string: "https://blink-363718.web.app/whatsnew/test.png")!, color: .orange, symbol: "person.badge.key.fill", link: nil)],
      [Feature(title: "Other Passkeys", description: "You can rock your own terminal and roll your own themes beyond our included ones.", image: nil, color: .purple, symbol: "globe", link: nil),
       Feature(title: "Simple", description: "No Munch", image: nil, color: .yellow, symbol: "ladybug.fill", link: nil)]
    )
]

class RowsViewModelDemo: RowsProvider {
    @Published var rows = [WhatsNewRow]()
    @Published var hasFetchedData = false
    static var baseURL = URL(fileURLWithPath: "")
    
    @MainActor
    func fetchData() async throws{
        rows = RowSamples
        try await Task.sleep(nanoseconds: 2_000_000_000)
        hasFetchedData = true
    }
}

enum WhatsNewRow: Identifiable {
    // NOTE We may want to have something more "abstract" than a "feature".
    // Items can also be "banners".
    // Or maybe a singleCol would be a "separator" as a banner.
    case oneCol(Feature)
    case twoCol([Feature], [Feature])
    case versionInfo(VersionInfo)

    var id: String {
        switch self {
        case .oneCol(let feature):
            return feature.title
        case .twoCol(let left, _):
            return left.reduce(String(), { $0.appending($1.title) })
        case .versionInfo(let info):
            return info.number
        }
    }
}

extension WhatsNewRow: Decodable {
    enum CodingKeys: CodingKey {
        case oneCol
        case twoCol
        case versionInfo
    }
    
    enum CodingError: Error {
        case decoding(String)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch container.allKeys.first {
        case .oneCol:
            let value = try container.decode(Feature.self, forKey: .oneCol)
            self = .oneCol(value)
        case .twoCol:
            let value = try container.decode([[Feature]].self, forKey: .twoCol)
            if value.count != 2 {
                throw CodingError.decoding("twoCol has wrong amount of columns")
            }
            self = .twoCol(value[0], value[1])
        case .versionInfo:
            let value = try container.decode(VersionInfo.self, forKey: .versionInfo)
            self = .versionInfo(value)
        default:
            throw CodingError.decoding("Unknown field \(container)")
        }
    }
}

enum FeatureColor: String, Decodable {
    case blue = "blue"
    case orange = "orange"
    case yellow = "yellow"
    case purple = "purple"
}

struct Feature: Identifiable, Decodable {
    let title: String
    let description: String
    var id: String { title }
    let image: URL?
    let color: FeatureColor
    let symbol: String
    let link: URL?
}

struct VersionInfo: Identifiable, Decodable {
    var id: String { number }
    let number: String
    let link: URL?
}
