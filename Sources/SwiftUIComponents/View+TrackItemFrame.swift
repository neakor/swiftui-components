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

extension View {
  /// Track this view's frame identified by the given ID.
  ///
  /// - Note: This is generally useful when this view is an item in a scroll view. Tracking this item view's frame can
  /// help perform various functions based on the item's frame. This modifier can be used in conjunction with the
  /// `onItemsFrameChange` applied to the parent view to observe items frame changes.
  ///
  /// - Parameters:
  ///   - itemId: The `String` ID that can be used to identify this item.
  /// - Returns: The modified item view.
  public func trackItemFrame(itemId: String, in coordinateNamespace: String) -> some View {
    // Cannot make itemId type generic, since the `ItemFramePreferenceKey` cannot support generics.
    background(
      GeometryReader { geometryReader in
        Color.clear
          .preference(
            key: ItemFramePreferenceKey.self,
            value: [itemId: geometryReader.frame(in: .named(coordinateNamespace))]
          )
      }
    )
    .id(itemId)
  }

  /// Perform action when tracked items frame changes.
  ///
  /// - Important: In order to use this modifier, the child views of this view must be modified with the
  /// `trackItemFrame` modifier. This is generally used on a scroll view whose item views are modified with the
  /// `trackItemFrame` modifier.
  ///
  /// - Parameters:
  ///   - handler: The closure to be invoked when any of the items frame changes.
  /// - Returns:The modified view.
  public func onItemsFrameChange(in coordinateNamespace: String, _ handler: @escaping ([String: CGRect]) -> Void) -> some View {
    // Cannot make key type generic, since the `ItemFramePreferenceKey` cannot support generics.
    coordinateSpace(name: coordinateNamespace)
      .onPreferenceChange(ItemFramePreferenceKey.self, perform: handler)
  }
}

// Cannot make the key type generic since static property does not support generic type.
private struct ItemFramePreferenceKey: PreferenceKey {
  fileprivate static var defaultValue = [String: CGRect]()

  fileprivate static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    for (key, frame) in nextValue() {
      value[key] = frame
    }
  }
}
