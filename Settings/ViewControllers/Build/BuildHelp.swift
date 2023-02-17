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

struct Cmd: Hashable, Equatable {
  let text: String
  let args: [(String, String)]
  
  func hash(into hasher: inout Hasher) {
    text.hash(into: &hasher)
  }
  
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.text == rhs.text
  }

}

extension Cmd: Identifiable {
  typealias ID = String
  var id: ID { text.description.uppercased() }
}


var cmds = [
  Cmd(text: "up", args: [
    ("<CONTAINER>", "Start named container"),
    ("node", "Start node container"),
    ("postgres", "Start postgres container"),
//    ("ansible", "Start ansible tools"),
    ("itzg/minecraft-server", "Start minecraft server"),
  ]),
  Cmd(text: "machine", args: [
    ("<sub-command>", "Manage your **build** machine"),
    ("start", "Start machine"),
    ("stop", "Stop machine"),
    ("status", "Show machine machine"),
    ("add-device", "Add **this** device to running machine")
  ]),
  Cmd(text: "mosh", args: [
    ("[<CONTAINER>]", "Mosh into container. Default container is htools"),
    ("ruby -c irb", "Start ruby container and mosh to irb")
  ]),
  Cmd(text: "down", args: [("<CONTAINER>", "Stop container")]),
  
  Cmd(text: "help", args: [("", "Show full cli help")])
]

var short_cmds = [
  Cmd(text: "up", args: [
    ("<NAME>", "Start named container"),
    ("node", "Start node container"),
    ("postgres", "Start postgres container"),
//    ("ansible", "Start ansible tools"),
  ]),
  Cmd(text: "machine", args: [
    ("<cmd>", "Manage your **build** machine"),
    ("start", "Start machine"),
    ("stop", "Stop machine"),
    ("status", "Show machine machine"),
    ("add-device", "Add **this** device to running machine")
  ]),
  Cmd(text: "mosh", args: [
    ("[<NAME>]", "Mosh into container. Default container is htools"),
    ("ruby -c irb", "Start ruby container and mosh to **irb**")
  ]),
  Cmd(text: "down", args: [("<NAME>", "Stop container")]),
  
  Cmd(text: "help", args: [("", "Show full cli help")])
  
]


extension VerticalAlignment {
  enum BuildAligment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
      context[VerticalAlignment.center]
    }
  }
  
  public static let buildAlignment = VerticalAlignment(BuildAligment.self)
}

public struct VTabView<Content, SelectionValue>: View where Content: View, SelectionValue: Hashable {
    
    private var selection: Binding<SelectionValue>?
    
    private var indexPosition: IndexPosition
    
    private var content: () -> Content
    
    /// Creates an instance that selects from content associated with
    /// `Selection` values.
    public init(selection: Binding<SelectionValue>?, indexPosition: IndexPosition = .leading, @ViewBuilder content: @escaping () -> Content) {
        self.selection = selection
        self.indexPosition = indexPosition
        self.content = content
    }
    
    private var flippingAngle: Angle {
        switch indexPosition {
        case .leading:
            return .degrees(0)
        case .trailing:
            return .degrees(180)
        }
    }
    
    public var body: some View {
        GeometryReader { proxy in
            TabView(selection: selection) {
              content()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .rotationEffect(.degrees(-90))
                .rotation3DEffect(flippingAngle, axis: (x: 1, y: 0, z: 0))
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(width: proxy.size.height, height: proxy.size.width)
            .rotation3DEffect(flippingAngle, axis: (x: 1, y: 0, z: 0))
            .rotationEffect(.degrees(90), anchor: .topLeading)
            .offset(x: proxy.size.width)
        }
    }
    
    public enum IndexPosition {
        case leading
        case trailing
    }
}

@available(iOS 14.0, *)
extension VTabView where SelectionValue == Int {
    
    public init(indexPosition: IndexPosition = .leading, @ViewBuilder content: @escaping () -> Content) {
        self.selection = nil
        self.indexPosition = indexPosition
        self.content = content
    }
}

struct FlipModifier: ViewModifier {
  let amount: Angle
  
  func body(content: Content) -> some View {
    content
      .rotation3DEffect(
        amount,
        axis: (x: 1.0, y: 0.0, z: 0.0),
        perspective: 0.7
      )
  }
  
  static var zero: Self {
    FlipModifier(amount: .zero)
  }
}

extension AnyTransition {
  public static func flip(duration: Double = 0.3) -> Self {
    let minDuration = 0.0002;
    let half = duration * 0.5 - minDuration;
    let fastOpacity = Self.opacity.animation(.linear(duration:minDuration).delay(half))
    
    return Self.asymmetric(
      insertion: .modifier(
        active: FlipModifier(amount: .degrees(-180)),
        identity: .zero
      ).combined(with: fastOpacity),
      removal: .modifier(
        active: FlipModifier(amount: .degrees(180)),
        identity: .zero
      ).combined(with: fastOpacity)
    )
    .animation(.easeInOut(duration: duration))
  }
}

struct CmdView: View {
  init(baseFont: Font, topOffset: CGFloat, cmd: Cmd, visible: Bool = false, idx: Int) {
    self.baseFont = baseFont
    self.cmd = cmd
    self.visible = visible
    self.topOffset = topOffset
    if idx < cmd.args.count {
      self.idx = idx
    } else {
      self.idx = 0
    }
  }
  
  let baseFont: Font
  let topOffset: CGFloat
  let cmd: Cmd
  var visible: Bool = false;
  let idx: Int
  
  var body: some View {
    VStack {
      Spacer().frame(height: topOffset)
      HStack(alignment: .firstTextBaseline) {
        // just to take same space
        Text("build").font(baseFont.monospaced()).hidden()
        Text(cmd.text).font(self.idx == 0 ? baseFont.monospaced().bold(): baseFont.monospaced()).fixedSize(horizontal: true, vertical: true)
          .transition(.opacity.animation(.linear(duration: 0.3)))
          .id("cmd \(self.idx == 0)")
        
        Text(self.cmd.args[self.idx].0).font(
          self.idx == 0 ? baseFont.monospaced() : baseFont.monospaced().bold()
        ).foregroundStyle(
          self.idx == 0 ? .secondary : .primary
        )
        .transition(.flip())
        .id("args \(self.idx)")
        .opacity( visible ? 1.0 : 0.0)
        .animation(.easeIn(duration: 0.2).delay(0.3), value: self.visible)
        Spacer()
      }
      HStack {
        Text("build").font(baseFont.monospaced()).hidden()
        Text(.init(self.cmd.args[self.idx].1)).font(.subheadline)
        Spacer()
      }
      .opacity(visible ? 1.0 : 0.0)
      .animation(.easeIn(duration: 0.3).delay(0.8), value: self.visible)
      Spacer()
    }
  }
}

struct GaugeProgressStyle: ProgressViewStyle {
  var strokeWidth = 4.0
  
  func makeBody(configuration: Configuration) -> some View {
    let fractionCompleted = configuration.fractionCompleted ?? 0
    let style = StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
    
    return ZStack {
      Circle()
        .stroke(Color.secondary, style: style)
        .opacity(0.3)
      Circle()
        .trim(from: 0, to: fractionCompleted)
        .stroke(Color.secondary, style: style)
        .rotationEffect(.degrees(-90))
    }
  }
}

struct CmdListView: View {
  let cmds: [Cmd]
  let topOffset: CGFloat
  let baseFont: Font
  let nspace : Namespace.ID;
  @State var idx: Int = 0
  @State var paused = false
  @State var timer: Timer? = nil
  
  @State var progressValue: Double = 0
  @State var page: Int = 0 {
    didSet {
      self.idx = 0
    }
  }
  
  var body: some View {
    ZStack(alignment: .leading) {
      VStack() {
        Spacer().frame(height: topOffset)
        Text("build").font(baseFont.monospaced()).matchedGeometryEffect(id: "logo", in: self.nspace)
        Spacer()
      }
      VTabView(selection: $page, indexPosition: .trailing) {
        ForEach(Array(cmds.enumerated()), id: \.element) { (index, cmd) in
          CmdView(baseFont: baseFont, topOffset: topOffset, cmd: cmd, visible: page == index, idx: self.idx).tag(index)
            .onAppear {
              self.idx = 0
              self.progressValue = 0
            }
        }
      }
    }
    .onTapGesture {
      showNext()
    }
    .overlay(content: {
      VStack {
        Spacer()
        HStack {
          ProgressView(value: min(progressValue, 1.0), total: 1.0)
            .progressViewStyle(GaugeProgressStyle())
            .frame(width: 38, height: 38)
            .overlay {
              VStack {
                Spacer()
                if paused {
                  Image(systemName: "play.fill").opacity(0.6)
                } else {
                  Image(systemName: "pause.fill").opacity(0.3)
                }
                Spacer()
              }
            }
            .padding(.bottom)
            .opacity(0.8)
            .contentShape(Rectangle())
            .onTapGesture {
              self.paused.toggle()
            }
          
          Spacer()
        }
      }
    })
    .onAppear {
      self.timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { t in
        if paused {
          return
        }
        withAnimation {
          self.progressValue += 0.05;
        }
        if self.progressValue >= 1.0 {
          self.showNext()
        }
        
      })
    }
  }
  
  func showNext() {
    let cmd = cmds[self.page]
    self.progressValue = 0
    withAnimation {
      if cmd.args.count > self.idx + 1 {
        self.idx += 1
      } else if cmds.count > self.page + 1 {
        self.idx = 0
        self.page += 1
      } else {
        self.idx = 0
        self.page = 0
      }
    }
    
  }
}

struct SizedCmdListView: View {
  let nspace : Namespace.ID;
  
  func baseFont(geom: GeometryProxy) -> Font {
    let width = geom.size.width
    if width > 400 {
      return .largeTitle
    } else if width > 300 {
      return .title2
    } else {
      return .title3
    }
  }
  
  var body: some View {
    GeometryReader { geom in
      let topOffset = geom.size.height * 0.5 - 30
      let baseFont = self.baseFont(geom: geom)
      let cmds = geom.size.width < 400 ? short_cmds : cmds
      
      CmdListView(cmds: cmds, topOffset: topOffset, baseFont: baseFont, nspace: self.nspace)
        .frame(width: geom.size.width, height: geom.size.height)
    }
  }
}


