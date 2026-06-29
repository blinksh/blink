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

import SwiftUI
import UIKit


class SettingsHostingController: UIHostingController<NavView<SettingsView>>, UIAdaptivePresentationControllerDelegate {
  private let onDismiss: (() -> Void)?

  private init(navController: UINavigationController, onDismiss: (() -> Void)? = nil) {
    self.onDismiss = onDismiss

    let rootView = NavView(navController: navController) {
      SettingsView()
    }

    super.init(rootView: rootView)

    navController.presentationController?.delegate = self
  }

  @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close, target: self, action: #selector(close))
  }

  private func tearDown() {
    onDismiss?()
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    tearDown()
  }

  @objc private func close() {
    dismiss(animated: true) { [weak self] in self?.tearDown() }
  }

  static func createSettings(nav: UINavigationController, onDismiss: (() -> Void)? = nil) -> UIViewController {
    return SettingsHostingController(navController: nav, onDismiss: onDismiss)
  }
}
