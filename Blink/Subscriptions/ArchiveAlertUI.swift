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


class ArchiveAlertUI {
  static func presentImport(on ctrl: UIViewController, cb: URL, archivePassword: String) {
    let alert = UIAlertController(
      title: "Data Export",
      message: "The new Blink.app is requesting permission to export your data. Do you want to continue?",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { _ in
      // Migration file to random location. Delete after read. Send to the callback.
      do {        
        let archiveURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo().globallyUniqueString)
        try Archive.export(to: archiveURL, password: archivePassword)
        let archiveData = try Data(contentsOf: archiveURL)
        let archiveB64 = archiveData.base64EncodedString()
        // Add parameter to URL
        let cbWithArchive = cb.appending([URLQueryItem(name: "archive", value: archiveB64)])!
        UIApplication.shared.open(cbWithArchive)
        
        // TODO Delete once done
      } catch {
        // Show error message
        self.presentArchiveOperationFailed(on: ctrl, error: error)
      }
    }))

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))
    ctrl.present(alert, animated: false, completion: nil)
  }

  static func performRecoveryWithFeedback(on ctrl: UIViewController, archiveData: Data, archivePassword: String) {
    // Put the archive on a temporary file.
    let archiveURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo().globallyUniqueString)
    do {
      try archiveData.write(to: archiveURL)
      try Archive.recover(from: archiveURL, password: archivePassword)
      PurchasesUserModel.shared.dataCopyFailed = false
      PurchasesUserModel.shared.dataCopied = true
      AppDelegate.reloadDefaults()
    } catch {
      PurchasesUserModel.shared.dataCopyFailed = false
      PurchasesUserModel.shared.dataCopied = false
      presentArchiveOperationFailed(on: ctrl, error: error)
    }
  }
  
  private static func presentArchiveOperationFailed(on ctrl: UIViewController, error: Error) {
    let alert = UIAlertController(title: "Error", message: "Error obtaining archive. \(error)", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Discard", style: .cancel))
    ctrl.present(alert, animated: false, completion: nil)
  }
}

fileprivate extension URL {
    func appending(_ queryItems: [URLQueryItem]) -> URL? {
        guard var urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        urlComponents.queryItems = (urlComponents.queryItems ?? []) + queryItems

        return urlComponents.url
    }
}
