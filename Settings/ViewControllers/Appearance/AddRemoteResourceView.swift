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

struct AddRemoteResourceView: View {
  struct Kind {
    let title: String
    let nounSingular: String
    let fileExtension: String
    let mimeTypes: [String]
    let galleryTopic: String
    let exists: (String) -> Bool
    let save: (String, Data) throws -> Void

    static let theme = Kind(
      title: "Add a new theme",
      nounSingular: "theme",
      fileExtension: "js",
      mimeTypes: ["application/javascript", "text/plain"],
      galleryTopic: "themes",
      exists: { BKTheme.withName($0) != nil },
      save: { name, data in
        _ = try BKTheme.save(name, withContent: data)
      }
    )

    static let font = Kind(
      title: "Add a new font",
      nounSingular: "font",
      fileExtension: "css",
      mimeTypes: ["text/css", "text/plain"],
      galleryTopic: "fonts",
      exists: { BKFont.withName($0) != nil },
      save: { name, data in
        _ = try BKFont.save(name, withContent: data)
      }
    )
  }

  let kind: Kind

  @EnvironmentObject private var nav: Nav

  @State private var name: String = ""
  @State private var urlText: String = ""
  @State private var downloadedData: Data?
  @State private var importTask: Task<Void, Never>?
  @State private var alert: AlertContent?

  private var urlIsWellFormed: Bool {
    guard let url = URL(string: urlText) else { return false }
    return url.scheme != nil && url.host != nil
  }

  private var isDownloading: Bool { importTask != nil }
  private var canSave: Bool { downloadedData != nil && !name.isEmpty && !isDownloading }

  var body: some View {
    Form {
      Section("Name") {
        TextField("Name", text: $name)
          .autocapitalization(.none)
          .disableAutocorrection(true)
      }

      Section {
        TextField("https://...", text: $urlText)
          .keyboardType(.URL)
          .autocapitalization(.none)
          .disableAutocorrection(true)
          .disabled(isDownloading)

        if isDownloading {
          Button("Cancel download", role: .destructive) { cancelDownload() }
        } else if downloadedData != nil {
          Text("Download complete")
            .foregroundColor(.secondary)
        } else {
          Button("Import") { startDownload() }
            .disabled(!urlIsWellFormed)
        }
      } header: {
        Text("Source")
      } footer: {
        Text("Themes are .js files. Fonts are .css files. GitHub blob URLs are accepted and rewritten to raw automatically.")
      }

      Section {
        Button {
          BKLinkActions.send(toGitHub: kind.galleryTopic)
        } label: {
          HStack {
            Text("Open Gallery on GitHub")
              .foregroundColor(.primary)
            Spacer()
            Image(systemName: "arrow.up.forward.square")
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Save") { save() }.disabled(!canSave)
      }
    }
    .alert(item: $alert) { content in
      Alert(title: Text(content.title), message: Text(content.message), dismissButton: .default(Text("OK")))
    }
    .onDisappear {
      importTask?.cancel()
    }
  }

  private func startDownload() {
    guard urlText.hasSuffix(".\(kind.fileExtension)") else {
      alert = AlertContent(
        title: "URL error",
        message: "\(kind.nounSingular.capitalized)s must be .\(kind.fileExtension) files. Open the gallery for examples."
      )
      return
    }

    let resolved = rewriteGitHubBlobToRaw(urlText)
    guard let url = URL(string: resolved) else {
      alert = AlertContent(title: "URL error", message: "Could not parse URL.")
      return
    }

    let mimes = kind.mimeTypes
    importTask = Task {
      defer { importTask = nil }
      do {
        let data = try await URLSession.downloadResource(from: url, expectedMIMETypes: mimes)
        if Task.isCancelled { return }
        downloadedData = data
      } catch is CancellationError {
        return
      } catch let urlError as URLError where urlError.code == .cancelled {
        return
      } catch {
        alert = AlertContent(title: "Download error", message: error.localizedDescription)
      }
    }
  }

  private func cancelDownload() {
    importTask?.cancel()
    importTask = nil
  }

  private func save() {
    guard let data = downloadedData else { return }
    if kind.exists(name) {
      alert = AlertContent(
        title: "\(kind.nounSingular.capitalized) error",
        message: "Cannot have two \(kind.nounSingular)s with the same name."
      )
      return
    }
    do {
      try kind.save(name, data)
      nav.navController.popViewController(animated: true)
    } catch {
      alert = AlertContent(
        title: "\(kind.nounSingular.capitalized) error",
        message: error.localizedDescription
      )
    }
  }

  private func rewriteGitHubBlobToRaw(_ url: String) -> String {
    guard url.contains("github.com"), !url.contains("/raw/") else { return url }
    return url.replacingOccurrences(of: "/blob/", with: "/raw/")
  }
}

private struct AlertContent: Identifiable {
  let id = UUID()
  let title: String
  let message: String
}

private extension URLSession {
  static func downloadResource(from url: URL, expectedMIMETypes: [String]) async throws -> Data {
    let (localURL, response) = try await URLSession.shared.download(from: url)
    if let mime = response.mimeType, !expectedMIMETypes.contains(mime) {
      throw NSError(
        domain: "BKSettingsErrorDomain",
        code: 415,
        userInfo: [NSLocalizedDescriptionKey: "Unsupported media type \(mime)."]
      )
    }
    return try Data(contentsOf: localURL)
  }
}
