//////////////////////////////////////////////////////////////////////////////////
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

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct BookmarkedLocationsView: View {
  private let locationsManager = BookmarkedLocationsManager.default
  @State private var locations: [BookmarkedLocation] = []
  @State private var showingDocumentPicker = false
  @State private var newLocationName = ""
  @State private var newLocationURL: URL? = nil
  @State private var showingErrorAlert = false
  @State private var errorMessage = ""
  @State private var dismissView = false
  @FocusState private var newLocationFocus: Bool
  @Environment(\.presentationMode) var presentationMode

  var body: some View {
    Group {
      if locations.isEmpty && newLocationURL == nil {
        EmptyStateView(
          action: Button(
            action: { showingDocumentPicker = true },
            label: { Label("Bookmark a new location", systemImage: "plus") }
          ),
          systemIconName: "bookmark",
          description: "Link locations from the Files.app to the Blink container and use them inside the shell.",
          learnMoreURL: URL(string: "https://docs.blink.sh")
        )
      } else {
        List {
          Section(footer: Text("Bookmarked locations are symlinked to your shell's Home directory and accessible via the CLI. [Learn More](https://docs.blink.sh/advanced/bookmarks)")) {
            ForEach(locations) { location in
              if location.isAvailable {
                Text(location.name)
              } else {
                HStack {
                  Text(location.name)
                  Spacer()
                  Text("Unavailable").font(.caption)
                }
                .foregroundColor(.secondary)
              }
            }
              .onDelete(perform: deleteLocation)

            if let newLocationURL = newLocationURL {
              TextField("Enter symlink name", text: $newLocationName, onCommit: {
                                                                        commitLocation(name: newLocationName, location: newLocationURL)
                                                                      })
                .focused($newLocationFocus)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onAppear { newLocationFocus = true }
                .submitLabel(.done)
            }
          }
        }
      }
    }
      .navigationTitle("Bookmarks")
      .navigationBarItems(trailing: Group {
        if let newLocationURL = self.newLocationURL {
          Button(action: { commitLocation(name: newLocationName, location: newLocationURL) })
            {
              Text("Done")
            }.disabled(newLocationName.isEmpty)
        } else {
          Button(action: {
            showingDocumentPicker = true
          }) {
            Image(systemName: "plus")
          }
        }
      })
      .fileImporter(isPresented: $showingDocumentPicker, allowedContentTypes: [.folder]) { result in
        handleDocumentPickerResult(result)
      }
      .alert("Error", isPresented: $showingErrorAlert) {
        Button("OK", role: .cancel) {
          if newLocationURL != nil {
            newLocationFocus = true
          } else if dismissView {
            presentationMode.wrappedValue.dismiss()
          }
        }
      } message: {
        Text(errorMessage)
      }
      .onAppear(perform: fetchLocations)
  }

  private func commitLocation(name: String, location: URL) {
    let name = name.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else {
      return
    }

    do {
      let addedLocation = try locationsManager.addLocation(name: name, location: location)
      resetNewLocation()
      locations.append(addedLocation)
      TerminalEnvironment.refreshAllowedPaths()
    } catch {
      if let error = error as? BookmarkedLocationsManager.Error {
        switch error {
        case .invalidFile(let error):
          errorMessage = "Error on ./blink/locations.json file: \(error.localizedDescription)"
          // Cannot retry
          resetNewLocation()
        case .locationNameExists:
          errorMessage = "Bookmark symlink with same name already exists."
        case .locationNotAvailable:
          errorMessage = "You do not have permission to access this location."
          // Cannot retry
          resetNewLocation()
        }
      } else {
        errorMessage = error.localizedDescription
      }
      showingErrorAlert = true
    }
  }

  private func fetchLocations() {
    do {
      locations = try locationsManager.getLocations()
    } catch {
      if let error = error as? BookmarkedLocationsManager.Error,
         case(.invalidFile(let internalError)) = error {
        errorMessage = "Could not open ./blink/locations.json file: \(internalError.localizedDescription)"
      } else {
        errorMessage = "\(error.localizedDescription)"
      }
      dismissView = true
    }
  }

  private func deleteLocation(at offsets: IndexSet) {
    for index in offsets {
      let location = locations[index]
      try? locationsManager.removeLocation(name: location.name)
    }
    TerminalEnvironment.refreshAllowedPaths()
    fetchLocations()
  }

  private func handleDocumentPickerResult(_ result: Result<URL, Error>) {
    switch result {
    case .success(let url):
      newLocationURL = url
      newLocationName = ""
    case .failure(let error):
      errorMessage = "Failed to select folder: \(error.localizedDescription)"
      showingErrorAlert = true
    }
  }

  private func resetNewLocation() {
    newLocationFocus = false
    // Avoid race with losing focus and deleting the row.
    DispatchQueue.main.async {
      newLocationURL = nil
      newLocationName = ""
    }
  }
}
