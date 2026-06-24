////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2024 Blink Mobile Shell Project
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
import Combine

import BlinkConfig

private struct StoreData: Codable {
  var styles: [TerminalStyle]
  var selectedStyleID: UUID?
}

@objc class TerminalStyleStore: NSObject, ObservableObject {
  @objc static let shared = TerminalStyleStore()

  @Published private(set) var styles: [TerminalStyle] = []
  @Published var selectedStyleID: UUID? = nil

  private let fileURL: URL

  let builtInDefault: TerminalStyle = TerminalStyle.makeBuiltInDefault()

  private override init() {
    let blinkDir = BlinkPaths.blinkURL()!
    self.fileURL = blinkDir.appendingPathComponent("styles")

    super.init()
    load()
  }

  private init(directory: URL) {
    self.fileURL = directory.appendingPathComponent("styles")
    super.init()
    load()
  }

  static func makeForTesting(directory: URL) -> TerminalStyleStore {
    TerminalStyleStore(directory: directory)
  }

  // MARK: - Computed

  var selectedStyle: TerminalStyle {
    if let id = selectedStyleID, let style = style(for: id) {
      return style
    }
    return builtInDefault
  }

  var allStyles: [TerminalStyle] {
    [builtInDefault] + styles
  }

  // MARK: - Lookup

  func style(for id: UUID) -> TerminalStyle? {
    if id == builtInDefault.id { return builtInDefault }
    return styles.first { $0.id == id }
  }

  // MARK: - Resolution

  func resolveSelected() -> TerminalStyle.Resolved {
    selectedStyle.resolved()
  }

  func resolve(_ id: UUID) -> TerminalStyle.Resolved {
    let s = style(for: id) ?? builtInDefault
    return s.resolved()
  }

  // MARK: - Create

  @discardableResult
  func createStyle(
    name: String,
    themeName: String = "Default",
    fontName: String? = nil,
    fontSize: CGFloat? = nil,
    cursorBlink: Bool = false,
    boldMode: TerminalStyle.BoldMode = .auto,
    boldAsBright: Bool = false
  ) -> TerminalStyle {
    let style = TerminalStyle(
      id: UUID(),
      name: uniqueName(for: name),
      themeName: themeName,
      fontName: fontName ?? builtInDefault.fontName,
      fontSize: fontSize ?? builtInDefault.fontSize,
      cursorBlink: cursorBlink,
      boldMode: boldMode,
      boldAsBright: boldAsBright
    )
    styles.append(style)
    save()
    return style
  }

  @discardableResult
  func duplicateStyle(_ id: UUID) -> TerminalStyle? {
    guard let original = style(for: id) else { return nil }
    let copy = TerminalStyle(
      id: UUID(),
      name: uniqueName(for: "\(original.name) Copy"),
      themeName: original.themeName,
      alternativeThemeName: original.alternativeThemeName,
      fontName: original.fontName,
      fontSize: original.fontSize,
      cursorBlink: original.cursorBlink,
      boldMode: original.boldMode,
      boldAsBright: original.boldAsBright
    )
    styles.append(copy)
    save()
    return copy
  }

  // Used by import path where the style already has identity
  @discardableResult
  internal func addStyle(_ style: TerminalStyle) -> TerminalStyle {
    let deduped = TerminalStyle(
      id: style.id,
      name: uniqueName(for: style.name),
      themeName: style.themeName,
      alternativeThemeName: style.alternativeThemeName,
      fontName: style.fontName,
      fontSize: style.fontSize,
      cursorBlink: style.cursorBlink,
      boldMode: style.boldMode,
      boldAsBright: style.boldAsBright
    )
    styles.append(deduped)
    save()
    return deduped
  }

  // MARK: - Update

  func updateStyle(_ style: TerminalStyle) {
    guard style.id != builtInDefault.id else { return }
    guard let idx = styles.firstIndex(where: { $0.id == style.id }) else { return }
    styles[idx] = style
    save()
  }

  func setSelected(_ id: UUID?) {
    if let id = id, id == builtInDefault.id {
      selectedStyleID = nil
    } else {
      selectedStyleID = id
    }
    save()
  }

  // MARK: - Delete

  func deleteStyle(_ id: UUID) {
    guard id != builtInDefault.id else { return }
    styles.removeAll { $0.id == id }
    if selectedStyleID == id {
      selectedStyleID = nil
    }
    save()
  }

  // MARK: - Persistence

  private func load() {
    guard
      let data = try? Data(contentsOf: fileURL),
      let stored = try? PropertyListDecoder().decode(StoreData.self, from: data)
    else {
      return
    }

    self.styles = stored.styles

    if let selectedID = stored.selectedStyleID,
       stored.styles.contains(where: { $0.id == selectedID }) {
      self.selectedStyleID = selectedID
    } else {
      self.selectedStyleID = nil
    }
  }

  private func save() {
    let envelope = StoreData(styles: styles, selectedStyleID: selectedStyleID)
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    guard let data = try? encoder.encode(envelope) else { return }
    try? data.write(to: fileURL, options: [.atomic, .noFileProtection])
  }

  // MARK: - ObjC Bridge

  @objc var bridgedThemeName: String { selectedStyle.themeName }
  @objc var bridgedFontName: String { selectedStyle.fontName }
  @objc var bridgedFontSize: NSNumber { NSNumber(value: Int(selectedStyle.fontSize)) }
  @objc var bridgedCursorBlink: Bool { selectedStyle.cursorBlink }
  @objc var bridgedEnableBold: UInt { UInt(selectedStyle.boldMode.rawValue) }
  @objc var bridgedBoldAsBright: Bool { selectedStyle.boldAsBright }

  @objc func setStyleThemeName(_ name: String) { updateSelectedStyle { $0.themeName = name } }
  @objc func setStyleFontName(_ name: String)  { updateSelectedStyle { $0.fontName = name } }
  @objc func setStyleFontSize(_ size: NSNumber) { updateSelectedStyle { $0.fontSize = CGFloat(size.intValue) } }
  @objc func setStyleCursorBlink(_ value: Bool) { updateSelectedStyle { $0.cursorBlink = value } }
  @objc func setStyleEnableBold(_ value: UInt)  { updateSelectedStyle { $0.boldMode = TerminalStyle.BoldMode(rawValue: Int(value)) ?? .auto } }
  @objc func setStyleBoldAsBright(_ value: Bool) { updateSelectedStyle { $0.boldAsBright = value } }

  private func updateSelectedStyle(_ mutate: (inout TerminalStyle) -> Void) {
    guard selectedStyleID != nil,
          var style = styles.first(where: { $0.id == selectedStyleID }) else {
      NSLog("[TerminalStyleStore] Warning: setter called with no user style selected, ignored.")
      return
    }
    mutate(&style)
    updateStyle(style)
  }

  // MARK: - Helpers

  private func uniqueName(for name: String) -> String {
    let existingNames = Set(allStyles.map(\.name))
    if !existingNames.contains(name) { return name }
    var suffix = 2
    while existingNames.contains("\(name) \(suffix)") {
      suffix += 1
    }
    return "\(name) \(suffix)"
  }
}
