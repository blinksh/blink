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

import XCTest
@testable import Blink

// MARK: - TerminalStyle Model Tests

class TerminalStyleTests: XCTestCase {

  func testBuiltInDefaultHasWellKnownID() {
    let d = TerminalStyle.makeBuiltInDefault()
    XCTAssertEqual(d.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    XCTAssertEqual(d.name, "Default")
  }

  func testEquality() {
    let a = TerminalStyle(
      id: UUID(), name: "Test", themeName: "Default", fontName: "Menlo",
      fontSize: 14,
      cursorBlink: true, boldMode: .on, boldAsBright: true
    )
    var b = a
    XCTAssertEqual(a, b)
    b.name = "Changed"
    XCTAssertNotEqual(a, b)
  }
}

// MARK: - Resolution Tests (require app bundle with themes/fonts)

class TerminalStyleResolutionTests: XCTestCase {

  func testResolveBuiltInDefault() {
    let d = TerminalStyle.makeBuiltInDefault()
    let r = d.resolved()
    XCTAssertNotNil(r.themeContent)
    XCTAssertNotNil(r.fontContent)
    XCTAssertFalse(r.fontFamily.isEmpty)
    XCTAssertFalse(r.hasWarnings)
  }

  func testResolveMissingThemeFallsBack() {
    let style = TerminalStyle(
      id: UUID(), name: "Broken", themeName: "NonexistentTheme123",
      fontName: "Source Code Pro", fontSize: 14,
      cursorBlink: false, boldMode: .auto, boldAsBright: false
    )
    let r = style.resolved()
    XCTAssertTrue(r.hasWarnings)
    XCTAssertTrue(r.warnings.contains(.themeNotFound(name: "NonexistentTheme123")))
    XCTAssertNotNil(r.themeContent)
  }

  func testResolveMissingFontFallsBack() {
    let style = TerminalStyle(
      id: UUID(), name: "Broken", themeName: "Default",
      fontName: "TotallyFakeFont999", fontSize: 14,
      cursorBlink: false, boldMode: .auto, boldAsBright: false
    )
    let r = style.resolved()
    XCTAssertTrue(r.hasWarnings)
    XCTAssertTrue(r.warnings.contains(.fontNotFound(name: "TotallyFakeFont999")))
    XCTAssertFalse(r.fontFamily.isEmpty)
  }

  func testResolveBothMissing() {
    let style = TerminalStyle(
      id: UUID(), name: "Empty", themeName: "NoTheme", fontName: "NoFont",
      fontSize: 14,
      cursorBlink: false, boldMode: .auto, boldAsBright: false
    )
    let r = style.resolved()
    XCTAssertEqual(r.warnings.count, 2)
  }
}

// MARK: - TerminalStyleStore Tests

class TerminalStyleStoreTests: XCTestCase {
  private var tempDir: URL!

  override func setUpWithError() throws {
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("TerminalStyleStoreTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: tempDir)
  }

  private func makeStore() -> TerminalStyleStore {
    TerminalStyleStore.makeForTesting(directory: tempDir)
  }

  func testFreshStoreHasOnlyBuiltInDefault() {
    let store = makeStore()
    XCTAssertTrue(store.styles.isEmpty)
    XCTAssertNil(store.selectedStyleID)
    XCTAssertEqual(store.allStyles.count, 1)
    XCTAssertEqual(store.selectedStyle.name, "Default")
  }

  func testCRUDBasics() {
    let store = makeStore()

    // Create
    let style = store.createStyle(name: "My Style")
    XCTAssertEqual(style.name, "My Style")
    XCTAssertEqual(store.styles.count, 1)
    XCTAssertEqual(store.allStyles.count, 2)

    // Name deduplication
    let second = store.createStyle(name: "My Style")
    XCTAssertEqual(second.name, "My Style 2")

    // Name conflict with built-in
    let third = store.createStyle(name: "Default")
    XCTAssertEqual(third.name, "Default 2")

    // Update
    var updated = style
    updated.fontSize = 20
    store.updateStyle(updated)
    XCTAssertEqual(store.style(for: style.id)?.fontSize, 20)

    // Cannot update built-in
    store.updateStyle(TerminalStyle(
      id: store.builtInDefault.id, name: "Hacked", themeName: "X", fontName: "X",
      fontSize: 99,
      cursorBlink: true, boldMode: .on, boldAsBright: true
    ))
    XCTAssertEqual(store.builtInDefault.name, "Default")

    // Delete
    store.deleteStyle(style.id)
    XCTAssertNil(store.style(for: style.id))

    // Cannot delete built-in
    store.deleteStyle(store.builtInDefault.id)
    XCTAssertEqual(store.allStyles.count, 3) // built-in + second + third
  }

  func testDuplicate() {
    let store = makeStore()
    let original = store.createStyle(name: "Original")
    let copy = store.duplicateStyle(original.id)
    XCTAssertNotNil(copy)
    XCTAssertNotEqual(copy!.id, original.id)
    XCTAssertEqual(copy!.themeName, original.themeName)

    // Can also duplicate built-in
    let defaultCopy = store.duplicateStyle(store.builtInDefault.id)
    XCTAssertNotNil(defaultCopy)
    XCTAssertNotEqual(defaultCopy!.id, store.builtInDefault.id)
  }

  func testDeleteSelectedStyleResetsToDefault() {
    let store = makeStore()
    let style = store.createStyle(name: "Test")
    store.setSelected(style.id)
    XCTAssertEqual(store.selectedStyleID, style.id)
    store.deleteStyle(style.id)
    XCTAssertNil(store.selectedStyleID)
    XCTAssertEqual(store.selectedStyle.id, store.builtInDefault.id)
  }

  func testSelectionEdgeCases() {
    let store = makeStore()
    let style = store.createStyle(name: "Test")

    store.setSelected(style.id)
    XCTAssertEqual(store.selectedStyle.id, style.id)

    // Setting to nil uses built-in
    store.setSelected(nil)
    XCTAssertEqual(store.selectedStyle.id, store.builtInDefault.id)

    // Setting to built-in ID stores nil
    store.setSelected(store.builtInDefault.id)
    XCTAssertNil(store.selectedStyleID)
  }

  // MARK: - Persistence

  func testPersistenceRoundTrip() {
    let style: TerminalStyle
    do {
      let store = makeStore()
      style = store.createStyle(name: "Persisted")
      store.setSelected(style.id)
    }

    let store2 = TerminalStyleStore.makeForTesting(directory: tempDir)
    XCTAssertEqual(store2.styles.count, 1)
    XCTAssertEqual(store2.styles.first?.name, "Persisted")
    XCTAssertEqual(store2.selectedStyleID, style.id)
  }

  func testCorruptFileBootstrapsFresh() {
    let fileURL = tempDir.appendingPathComponent("styles")
    try! "garbage data".data(using: .utf8)!.write(to: fileURL)

    let store = TerminalStyleStore.makeForTesting(directory: tempDir)
    XCTAssertTrue(store.styles.isEmpty)
    XCTAssertNil(store.selectedStyleID)
  }

  func testInvalidSelectedIDFallsBack() {
    let style = TerminalStyle(
      id: UUID(), name: "Orphan", themeName: "Default", fontName: "Source Code Pro",
      fontSize: 14,
      cursorBlink: false, boldMode: .auto, boldAsBright: false
    )
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary

    struct StoreData: Codable {
      var styles: [TerminalStyle]
      var selectedStyleID: UUID?
    }
    let data = try! encoder.encode(StoreData(styles: [style], selectedStyleID: UUID()))
    try! data.write(to: tempDir.appendingPathComponent("styles"))

    let store = TerminalStyleStore.makeForTesting(directory: tempDir)
    XCTAssertEqual(store.styles.count, 1)
    XCTAssertNil(store.selectedStyleID, "Invalid selectedStyleID should reset to nil")
  }

  func testLossyDecodeSkipsBadStyleKeepsOthers() throws {
    // A valid style as a plist dictionary.
    let good = TerminalStyle(
      id: UUID(), name: "Good", themeName: "Default", fontName: "Menlo",
      fontSize: 12, cursorBlink: false, boldMode: .auto, boldAsBright: false
    )
    let goodData = try PropertyListEncoder().encode(good)
    let goodDict = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: goodData, options: [], format: nil) as? [String: Any]
    )

    // A broken entry: same shape, but missing the required `name`.
    var badDict = goodDict
    badDict["id"] = UUID().uuidString
    badDict.removeValue(forKey: "name")

    let storeDict: [String: Any] = ["styles": [goodDict, badDict]]
    let data = try PropertyListSerialization.data(fromPropertyList: storeDict, format: .binary, options: 0)
    try data.write(to: tempDir.appendingPathComponent("styles"))

    let store = TerminalStyleStore.makeForTesting(directory: tempDir)
    XCTAssertEqual(store.styles.count, 1, "The bad entry is dropped, the good one kept")
    XCTAssertEqual(store.styles.first?.name, "Good")
  }
}

// MARK: - TerminalStyleBundle Tests

class TerminalStyleBundleTests: XCTestCase {

  private func makeStyle(name: String = "Shared") -> TerminalStyle {
    TerminalStyle(
      id: UUID(), name: name, themeName: "Default", fontName: "Source Code Pro",
      fontSize: 16,
      cursorBlink: true, boldMode: .on, boldAsBright: false
    )
  }

  func testExportBuiltInResourcesDoesNotEmbedContent() {
    let style = makeStyle()
    let bundle = TerminalStyleBundle.export(style: style)
    // Built-in theme/font should not be embedded (they ship with the app)
    XCTAssertNil(bundle.embeddedThemeContent)
    XCTAssertNil(bundle.embeddedThemeName)
    XCTAssertNil(bundle.embeddedFontContent)
    XCTAssertNil(bundle.embeddedFontName)
    // Style data and metadata are always present
    XCTAssertEqual(bundle.style, style)
    XCTAssertNotNil(bundle.blinkVersion)
    XCTAssertNotNil(bundle.exportDate)
  }

  func testBundleJSONRoundTrip() throws {
    let style = makeStyle(name: "RoundTrip")
    let bundle = TerminalStyleBundle.export(style: style)
    let data = try bundle.encode()
    let decoded = try TerminalStyleBundle.decode(from: data)
    XCTAssertEqual(decoded.style, style)
  }

  func testImportNewStyle() {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("BundleImportTest-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let store = TerminalStyleStore.makeForTesting(directory: tempDir)
    let style = makeStyle(name: "Imported")
    let bundle = TerminalStyleBundle.export(style: style)
    let result = bundle.importInto(store: store)

    switch result {
    case .success(let imported):
      XCTAssertEqual(imported.name, "Imported")
      XCTAssertEqual(imported.id, style.id)
      XCTAssertEqual(store.styles.count, 1)
    case .alreadyExists:
      XCTFail("Should not report alreadyExists for a new style")
    case .successWithWarnings:
      break // acceptable
    }
  }

  func testImportDuplicateUUIDReturnsAlreadyExists() {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("BundleDupeTest-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let store = TerminalStyleStore.makeForTesting(directory: tempDir)
    let style = makeStyle(name: "Original")
    store.addStyle(style)

    let bundle = TerminalStyleBundle.export(style: style)
    let result = bundle.importInto(store: store)

    switch result {
    case .alreadyExists(let existing, let incoming):
      XCTAssertEqual(existing.id, incoming.id)
    default:
      XCTFail("Expected alreadyExists for duplicate UUID import")
    }
  }
}

// MARK: - Migration / forward-compatible decode

// Guards that data written by an older schema still decodes. As fields are
// added, extend `dropping:` with the new keys and assert their defaults — old
// on-disk data lacks them, so decode must recover rather than throw (a throw
// here is what makes the store drop saved styles on load).
final class TerminalStyleMigrationTests: XCTestCase {

  // A fully-populated current style, used as the base to strip fields from.
  private let base = TerminalStyle(
    id: UUID(),
    name: "Base",
    themeName: "Theme",
    alternativeThemeName: "Alt",
    appearance: .dark,
    fontName: "Font",
    fontSize: 12,
    cursorBlink: true,
    boldMode: .on,
    boldAsBright: true
  )

  /// Encodes `style`, drops `keys` from the serialized plist to mimic an older
  /// on-disk schema, then decodes back through the real decoder.
  private func decode(_ style: TerminalStyle, dropping keys: [String]) throws -> TerminalStyle {
    let data = try PropertyListEncoder().encode(style)
    var plist = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    )
    keys.forEach { plist.removeValue(forKey: $0) }
    let stripped = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    return try PropertyListDecoder().decode(TerminalStyle.self, from: stripped)
  }

  func testDecodesWhenAppearanceFieldsAreAbsent() throws {
    let recovered = try decode(base, dropping: ["appearance", "alternativeThemeName"])
    XCTAssertEqual(recovered.appearance, .system)   // default for a missing field
    XCTAssertNil(recovered.alternativeThemeName)     // default for a missing field
    XCTAssertEqual(recovered.themeName, "Theme")     // pre-existing fields survive
    XCTAssertEqual(recovered.fontName, "Font")
  }

  func testFullStyleRoundTrips() throws {
    let data = try PropertyListEncoder().encode(base)
    let decoded = try PropertyListDecoder().decode(TerminalStyle.self, from: data)
    XCTAssertEqual(decoded.appearance, .dark)
    XCTAssertEqual(decoded.alternativeThemeName, "Alt")
  }
}
