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

private let contentOffsetTrackingScrollViewCoordinateSpaceName = "ContentOffsetTrackingScrollViewCoordinateSpaceName"

extension View {
  /// Track this view's content offset in a scroll view.
  ///
  /// - Note: This modifier should only be used for the content view embedded in a `ScrollView`. When the scroll
  /// view's content offset changes, the new value can be handled via the `onContentOffsetChange`modifier on the
  /// scroll view itself.
  ///
  /// - Returns:The modified scroll view.
  public func trackContentOffset() -> some View {
    background(
      GeometryReader { geometryProxy in
        Color.clear
          .preference(
            key: ScrollContentOffsetPreferenceKey.self,
            value: geometryProxy.frame(in: .named(contentOffsetTrackingScrollViewCoordinateSpaceName)).origin
          )
      }
    )
  }
}

extension ScrollView {
  /// Perform an action when this scroll view's content's offset changes.
  ///
  /// - Important: In order to use this modifier, the content of this scroll view must be modified with the
  /// `trackContentOffset` modifier.
  ///
  /// - Parameters:
  ///   - handler: The closure to be invoked when the content's offset changes.
  /// - Returns:The modified scroll view.
  public func onContentOffsetChange(_ handler: @escaping (CGPoint) -> Void) -> some View {
    coordinateSpace(name: contentOffsetTrackingScrollViewCoordinateSpaceName)
      .onPreferenceChange(ScrollContentOffsetPreferenceKey.self, perform: handler)
  }
}

private struct ScrollContentOffsetPreferenceKey: PreferenceKey {
  fileprivate static var defaultValue = CGPoint()

  // Nothing to reduce into since this is just tracking one scroll view's content's offset.
  fileprivate static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
}
