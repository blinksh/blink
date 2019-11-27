//
//  KBView.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/26/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import UIKit

class KBWebView: KBWebViewBase {
  
  func configure(_ kbConfig: KBConfig) {
    guard
      let data = try? JSONEncoder().encode(kbConfig),
      let json = String(data: data, encoding: .utf8)
    else {
      debugPrint("Can't encode kbConfig")
      return
    }

    report("config", arg: json as NSString)
  }
  
  
  override func ready() {
    configure(KBConfig())
  }
  
  func loadKB() {
    let bundle = Bundle.init(for: KBWebView.self)
    guard
      let path = bundle.path(forResource: "kb", ofType: "html")
    else {
      return
    }
    let url = URL(fileURLWithPath: path)
    loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
  }
}
