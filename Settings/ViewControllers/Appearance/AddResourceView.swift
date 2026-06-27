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

import SwiftUI
import UniformTypeIdentifiers

/// Hosts the Local/Remote switch and routes to the matching import view.
struct AddResourceView: View {
  enum ResourceType {
    case theme
    case font

    var title: String {
      switch self {
      case .theme: return "Add Theme"
      case .font: return "Add Font"
      }
    }
  }

  private enum Source: Hashable {
    case local
    case remote
  }

  let resourceType: ResourceType

  @State private var source: Source = .local

  var body: some View {
    VStack(spacing: 0) {
      Picker("Source", selection: $source) {
        Text("Local").tag(Source.local)
        Text("Remote").tag(Source.remote)
      }
      .pickerStyle(.segmented)
      .padding()

      switch source {
      case .local:
        switch resourceType {
        case .theme: AddLocalThemeView()
        case .font: AddLocalFontView()
        }
      case .remote:
        AddRemoteResourceView(kind: resourceType == .theme ? .theme : .font)
      }
    }
    .navigationTitle(resourceType.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - Local Theme Import

/// Imports a theme from a local color-scheme file into the custom resources.
struct AddLocalThemeView: View {
  @EnvironmentObject private var nav: Nav

  @State private var name: String = ""
  @State private var file: ImportedFile?
  @State private var pickerPresented = false
  @State private var alert: ImportAlert?

  private var canSave: Bool { file != nil && !name.isEmpty }

  var body: some View {
    Form {
      Section("Name") {
        TextField("Name", text: $name)
          .autocapitalization(.none)
          .disableAutocorrection(true)
      }

      Section {
        Button {
          pickerPresented = true
        } label: {
          HStack {
            Text(file?.filename ?? "Choose a file…")
              .foregroundColor(file == nil ? .accentColor : .primary)
            Spacer()
            if file != nil {
              Image(systemName: "checkmark").foregroundColor(.secondary)
            }
          }
        }
      } header: {
        Text("Theme file")
      } footer: {
        Text("Select a theme .js file. It is copied into Blink so it cannot be lost.")
      }
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Save") { save() }.disabled(!canSave)
      }
    }
    .fileImporter(isPresented: $pickerPresented, allowedContentTypes: ImportedFile.themeContentTypes) { result in
      handlePick(result)
    }
    .alert(item: $alert) { content in
      Alert(title: Text(content.title), message: Text(content.message), dismissButton: .default(Text("OK")))
    }
  }

  private func handlePick(_ result: Result<URL, Error>) {
    switch result {
    case .failure(let error):
      alert = ImportAlert(title: "Import error", message: error.localizedDescription)
    case .success(let url):
      do {
        let imported = try ImportedFile(contentsOf: url)
        file = imported
        if name.isEmpty {
          name = imported.baseName
        }
      } catch {
        alert = ImportAlert(title: "Import error", message: error.localizedDescription)
      }
    }
  }

  private func save() {
    guard let file else { return }
    if BKTheme.withName(name) != nil {
      alert = ImportAlert(title: "Theme error", message: "Cannot have two themes with the same name.")
      return
    }
    do {
      _ = try BKTheme.save(name, withContent: file.data)
    } catch {
      alert = ImportAlert(title: "Theme error", message: error.localizedDescription)
      return
    }
    nav.navController.popViewController(animated: true)
  }
}

// MARK: - Local Font Import

/// Imports up to four font variants (Regular required) as an embedded
/// `@font-face` stylesheet with each file inlined as base64.
struct AddLocalFontView: View {
  @EnvironmentObject private var nav: Nav

  @State private var name: String = ""
  @State private var files: [FontVariant: ImportedFile] = [:]
  @State private var pickerPresented = false
  @State private var pendingVariant: FontVariant?
  @State private var alert: ImportAlert?

  private var canSave: Bool { files[.regular] != nil && !name.isEmpty }

  var body: some View {
    Form {
      Section("Name") {
        TextField("Name", text: $name)
          .autocapitalization(.none)
          .disableAutocorrection(true)
      }

      Section {
        ForEach(FontVariant.allCases) { variant in
          Button {
            pendingVariant = variant
            pickerPresented = true
          } label: {
            variantRow(variant)
          }
        }
      } header: {
        Text("Font files")
      } footer: {
        Text("Only Regular is required. Accepted formats: ttf, otf, woff, woff2. Files are embedded into Blink so they cannot be lost.")
      }
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Save") { save() }.disabled(!canSave)
      }
    }
    .fileImporter(isPresented: $pickerPresented, allowedContentTypes: ImportedFile.fontContentTypes) { result in
      handlePick(result)
    }
    .alert(item: $alert) { content in
      Alert(title: Text(content.title), message: Text(content.message), dismissButton: .default(Text("OK")))
    }
  }

  @ViewBuilder
  private func variantRow(_ variant: FontVariant) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(variant.label).foregroundColor(.primary)
        if let file = files[variant] {
          Text(file.filename)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Spacer()
      if files[variant] != nil {
        Image(systemName: "checkmark").foregroundColor(.secondary)
      } else {
        Text(variant.required ? "Required" : "Optional")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }

  private func handlePick(_ result: Result<URL, Error>) {
    guard let variant = pendingVariant else { return }
    pendingVariant = nil

    switch result {
    case .failure(let error):
      alert = ImportAlert(title: "Import error", message: error.localizedDescription)
    case .success(let url):
      do {
        let imported = try ImportedFile(contentsOf: url)
        guard imported.fontFormat != nil else {
          alert = ImportAlert(
            title: "Font error",
            message: "Unsupported font file. Use ttf, otf, woff, or woff2."
          )
          return
        }
        files[variant] = imported
        if variant == .regular, name.isEmpty {
          name = imported.baseName
        }
      } catch {
        alert = ImportAlert(title: "Import error", message: error.localizedDescription)
      }
    }
  }

  private func save() {
    guard files[.regular] != nil else { return }
    if BKFont.withName(name) != nil {
      alert = ImportAlert(title: "Font error", message: "Cannot have two fonts with the same name.")
      return
    }
    guard let css = makeFontFaceCSS(family: name) else {
      alert = ImportAlert(title: "Font error", message: "Could not generate the font stylesheet.")
      return
    }
    do {
      _ = try BKFont.save(name, withContent: css)
    } catch {
      alert = ImportAlert(title: "Font error", message: error.localizedDescription)
      return
    }
    nav.navController.popViewController(animated: true)
  }

  /// The terminal detects the family from the first `font-family` declaration,
  /// so every variant declares the same one.
  private func makeFontFaceCSS(family: String) -> Data? {
    let blocks: [String] = FontVariant.allCases.compactMap { variant in
      guard let file = files[variant], let format = file.fontFormat else { return nil }
      let base64 = file.data.base64EncodedString()
      return """
      @font-face {
        font-family: '\(family)';
        src: url(data:\(format.mimeType);base64,\(base64)) format('\(format.cssFormat)');
        font-weight: \(variant.weight);
        font-style: \(variant.style);
      }
      """
    }
    guard !blocks.isEmpty else { return nil }
    return blocks.joined(separator: "\n\n").data(using: .utf8)
  }
}

// MARK: - Supporting types

/// UI and stylesheet order; Regular first so it is the detected family.
private enum FontVariant: CaseIterable, Identifiable {
  case regular
  case italic
  case bold
  case boldItalic

  var id: Self { self }

  var label: String {
    switch self {
    case .regular: return "Regular"
    case .italic: return "Italic"
    case .bold: return "Bold"
    case .boldItalic: return "Bold Italic"
    }
  }

  var required: Bool { self == .regular }

  var weight: String {
    switch self {
    case .bold, .boldItalic: return "bold"
    case .regular, .italic: return "normal"
    }
  }

  var style: String {
    switch self {
    case .italic, .boldItalic: return "italic"
    case .regular, .bold: return "normal"
    }
  }
}

private struct FontFormat {
  let mimeType: String
  let cssFormat: String

  static func forExtension(_ ext: String) -> FontFormat? {
    switch ext.lowercased() {
    case "ttf": return FontFormat(mimeType: "font/ttf", cssFormat: "truetype")
    case "otf": return FontFormat(mimeType: "font/otf", cssFormat: "opentype")
    case "woff": return FontFormat(mimeType: "font/woff", cssFormat: "woff")
    case "woff2": return FontFormat(mimeType: "font/woff2", cssFormat: "woff2")
    default: return nil
    }
  }
}

/// Read into memory at selection time, so the security-scoped URL need not outlive the picker.
private struct ImportedFile {
  let filename: String
  let ext: String
  let data: Data

  var baseName: String { (filename as NSString).deletingPathExtension }
  var fontFormat: FontFormat? { FontFormat.forExtension(ext) }

  init(contentsOf url: URL) throws {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    self.data = try Data(contentsOf: url)
    self.filename = url.lastPathComponent
    self.ext = url.pathExtension.lowercased()
  }

  static var themeContentTypes: [UTType] {
    [.javaScript, .plainText, .text, .data]
  }

  static var fontContentTypes: [UTType] {
    var types: [UTType] = [.font]
    for ext in ["ttf", "otf", "woff", "woff2"] {
      if let type = UTType(filenameExtension: ext) {
        types.append(type)
      }
    }
    return types
  }
}

private struct ImportAlert: Identifiable {
  let id = UUID()
  let title: String
  let message: String
}
