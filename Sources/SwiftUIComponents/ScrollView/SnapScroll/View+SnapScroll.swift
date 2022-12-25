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
import Introspect
import SwiftUI

extension View {
  /// Modify the scroll view to snap to the next item in a scrolling action.
  ///
  /// - Note: All items in the scroll view must be of the same size in the axis of scrolling. The size can either
  /// be explicitly specified via the `frame` modifier or obtained via a `GeometryReader`.
  ///
  /// - Important: The handler object must be retained by the parent view. Generally this object can be either created
  /// as a `StateObject` within a view or as a property of a view's view model.
  public func snapScroll(using handler: ScrollViewSnapHandler) -> some View {
    introspectScrollView { scrollView in
      // Setup snap scroll on the next runloop cycle to avoid flakiness. Without this delay, the setup sometimes is
      // not performed.
      DispatchQueue.main.async {
        scrollView.decelerationRate = .fast
        scrollView.delegate = handler
      }
    }
  }
}

#if DEBUG
private let itemHeight = 100.0
private let itemSpacing = 12.0

struct SnapScrollView: View {
  @StateObject private var snapHandler: ScrollViewSnapHandler

  init(snapBehavior: ScrollViewSnapHandler.Behavior) {
    _snapHandler = StateObject(wrappedValue: ScrollViewSnapHandler(
      behavior: snapBehavior,
      axis: .y,
      itemSize: itemHeight + itemSpacing
    ))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .center, spacing: itemSpacing) {
        coloredBlocks
      }
    }
    .snapScroll(using: snapHandler)
    .background(.white)
  }

  private var coloredBlocks: some View {
    ForEach(0..<100, id: \.self) { index in
      if index % 2 == 0 {
        Text("\(index)")
          .frame(maxWidth: .infinity)
          .frame(height: itemHeight)
          .background(.red)
      } else {
        Text("\(index)")
          .frame(maxWidth: .infinity)
          .frame(height: itemHeight)
          .background(.blue)
      }
    }
  }
}

struct SnapScrollViewPreviewProvider: PreviewProvider {
  static var previews: some View {
    SnapScrollView(snapBehavior: .singleItem).previewDisplayName("single item")
    SnapScrollView(snapBehavior: .allowMultiItems).previewDisplayName("multi items")
  }
}
#endif
