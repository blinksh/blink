//
//  Checkmark.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import SwiftUI

struct Checkmark: View {
  var checked: Bool = true
  
  var body: some View {
    Group {
      if checked {
        Image(systemName: "checkmark")
      } else {
        EmptyView()
      }
    }
  }
}

struct Checkmark_Previews: PreviewProvider {
  static var previews: some View {
    Checkmark()
  }
}
