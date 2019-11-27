//
//  NavView.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import UIKit
import SwiftUI

class Nav: ObservableObject {
  let navController: UINavigationController
  
  init(navController: UINavigationController) {
    self.navController = navController
  }
}

struct NavView<Content: View>: View {
  var content: () -> Content
  let nav: Nav
  
  init(navController: UINavigationController, content: @escaping () -> Content) {
    self.content = content
    self.nav = Nav(navController: navController)
  }
  
  var body: some View {
    content().environmentObject(nav)
  }
}

