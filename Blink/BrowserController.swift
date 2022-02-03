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
import UIKit
import WebKit

@objc public class BrowserController: UIViewController {
  
  @objc public var webView: WKWebView? = nil {
    didSet {
      oldValue?.removeFromSuperview()
      if let web = webView {
        view.addSubview(web)
      }
    }
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    navigationItem.leftBarButtonItems = [
      UIBarButtonItem(
        image: UIImage(systemName: "arrow.left"),
        style: .plain,
        target: self,
        action: #selector(_goBack)
      ),
      UIBarButtonItem(
        image: UIImage(systemName: "arrow.right"),
        style: .plain,
        target: self,
        action: #selector(_goForward)
      ),
    ]
    
    navigationItem.rightBarButtonItems = [
      UIBarButtonItem(
        barButtonSystemItem: .close,
        target: self,
        action: #selector(_close)
      ),
      UIBarButtonItem(
        barButtonSystemItem: .refresh,
        target: self,
        action: #selector(_reload)
      ),
      UIBarButtonItem(
        image: UIImage(systemName: "safari"),
        style: .plain,
        target: self,
        action: #selector(_openBrowser)
      ),
    ]
    
  }
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    webView?.frame = self.view.bounds
  }
  
  @objc func _goBack() {
    webView?.goBack()
  }
  
  @objc func _goForward() {
    webView?.goForward()
  }
  
  @objc func _reload() {
    webView?.reloadFromOrigin()
  }
  
  @objc func _close() {
    self.dismiss(animated: true) {
        
    }
  }
  
  @objc func _openBrowser() {
    if let url = webView?.url {
      blink_openurl(url)
    }
  }
}
