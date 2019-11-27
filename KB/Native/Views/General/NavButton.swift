//
//  NavButton.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import SwiftUI

struct NavButton<Details: View>: View {
  @EnvironmentObject var nav: Nav
  var details: () ->  Details
  
  var body: some View {
    Button(action: {
      let rootView = self.details().environmentObject(self.nav)
      let vc = UIHostingController(rootView: rootView)
      self.nav.navController.pushViewController(vc, animated: true)
    }, label: { EmptyView() })
  }
}

struct NavButton_Previews: PreviewProvider {
  static var previews: some View {
    NavButton {
      Text("Nice")
    }
  }
}
