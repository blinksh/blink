//
//  Row.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import SwiftUI

struct Row<Content: View, Details: View>: View {
  var content: () ->  Content
  var details: () ->  Details
  
  var body: some View {
    HStack {
      content()
      Spacer()
      Chevron()
    }
    .overlay(NavButton(details: details))
  }
}

struct Row_Previews: PreviewProvider {
  static var previews: some View {
    Row(content: {Text("Row")}, details: {EmptyView()})
  }
}
