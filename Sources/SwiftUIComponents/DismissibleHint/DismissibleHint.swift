// MIT License
//
// Copyright (c) 2022 Yi Wang
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import SwiftUI

public struct DismissibleHint<Content: View>: View {
  private let dismissSwipeDirection: SwipeDirection
  private let showHint: Binding<Bool>
  private let isDayTime: Bool
  private let content: Content

  public init(
    dismissSwipeDirection: SwipeDirection,
    showHint: Binding<Bool>,
    isDayTime: Bool,
    contentBuilder: () -> Content
  ) {
    self.dismissSwipeDirection = dismissSwipeDirection
    self.showHint = showHint
    self.isDayTime = isDayTime
    self.content = contentBuilder()
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 8) {
      styledContent
      Spacer(minLength: 0)
    }
    .padding(16)
    .background(.ultraThinMaterial)
    .onTapGesture(perform: hide)
    .onSwipe { directions in
      if directions.contains(dismissSwipeDirection) {
        hide()
      }
    }
    .transition(.move(edge: transitionEdge))
    .onAppear(perform: hideAfterDelay)
  }

  private var styledContent: some View {
    content.font(.callout)
  }

  private var transitionEdge: Edge {
    switch dismissSwipeDirection {
    case .up:
      return .top
    case .down:
      return .bottom
    case .left:
      return .leading
    case .right:
      return .trailing
    }
  }

  private func hide() {
    withAnimation {
      showHint.wrappedValue = false
    }
  }

  private func hideAfterDelay() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
      hide()
    }
  }
}

#if DEBUG
class DismissibleHintPreviewViewModel: ObservableObject {
  @Published var showHint = true
}

struct DismissibleHintPreview: View {
  @ObservedObject var viewModel: DismissibleHintPreviewViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer()

      if viewModel.showHint {
        DismissibleHint(dismissSwipeDirection: .down, showHint: $viewModel.showHint, isDayTime: true) {
          Text("Swipe left or right to see today, tonight and tomorrow's forecast")
        }
      }
    }
  }
}

struct DismissibleHintPreviewProvider: PreviewProvider {
  private static var viewModel = DismissibleHintPreviewViewModel()

  static var previews: some View {
    DismissibleHintPreview(viewModel: viewModel)
    DismissibleHintPreview(viewModel: viewModel).preferredColorScheme(.dark)
  }
}
#endif
