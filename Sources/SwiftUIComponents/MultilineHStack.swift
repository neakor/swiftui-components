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

/// A `MultilineHStack` lays out a list of items horizontally and overflows to multiple lines if necessary.
public struct MultilineHStack<ItemData: Hashable, ItemView: View>: View {
  private let itemsData: [ItemData]
  private let itemBuilder: (ItemData) -> ItemView
  @State private var stackHeight: CGFloat = 0

  /// Initializer.
  /// - Parameters:
  ///   - itemsData: The list of data to to be shown.
  ///   - itemBuilder: The view builder producing a view for a single item in the data list.
  public init(itemsData: [ItemData], itemBuilder: @escaping (ItemData) -> ItemView) {
    self.itemsData = itemsData
    self.itemBuilder = itemBuilder
  }

  public var body: some View {
    var width: CGFloat = 0
    var height: CGFloat = 0

    VStack {
      GeometryReader { geometryReader in
        ZStack(alignment: .topLeading) {
          ForEach(itemsData, id: \.self) { data in
            itemBuilder(data)
              .alignmentGuide(.leading) { viewDimensions in
                if abs(width - viewDimensions.width) > geometryReader.size.width {
                  width = 0
                  height -= viewDimensions.height
                }

                let result = width

                if let last = itemsData.last, data == last {
                  width = 0
                } else {
                  width -= viewDimensions.width
                }

                return result
              }
              .alignmentGuide(.top) { _ in
                let result = height

                if let last = itemsData.last, data == last {
                  height = 0
                }

                return result
              }
          }
        }
        .background(updateStackHeight)
      }
    }
    .frame(height: stackHeight)
  }

  private var updateStackHeight: some View {
    GeometryReader { geometryReader in
      let height = geometryReader.frame(in: .local).height
      DispatchQueue.main.async {
        if height >= 0, height.isFinite {
          stackHeight = height
        }
      }
      return Color.clear
    }
  }
}

#if DEBUG
struct MultilineHStackPreviews: PreviewProvider {
  static var previews: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 16) {
        multiline
        Divider()
        singleLine
      }
      .padding(16)
    }
  }

  private static var multiline: some View {
    MultilineHStack(itemsData: [
      "Tag 1",
      "Tag 2",
      "Tag 3",
      "A really really really really really long tag",
      "Tag 4",
      "Tag 5",
      "Tag 6",
      "Tag 7"
    ]) { tag in
      tagView(tag: tag)
        .id(tag)
        .padding([.vertical, .horizontal], 4)
    }
  }

  private static var singleLine: some View {
    MultilineHStack(itemsData: [
      "Tag 1",
      "Tag 2",
      "Tag 3",
    ]) { tag in
      tagView(tag: tag)
        .id(tag)
        .padding([.vertical, .horizontal], 4)
    }
  }

  private static func tagView(tag: String) -> some View {
    Text(tag)
      .foregroundColor(.white)
      .font(Font.system(size: 14))
      .padding(.vertical, 4)
      .padding(.horizontal, 8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.gray)
      )
  }
}
#endif
