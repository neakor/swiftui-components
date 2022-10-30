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

import Combine
import Foundation
import Introspect
import SwiftUI

extension ScrollView {
  /// Keep this scroll view's scroll position static when new items are prepended to the head.
  ///
  /// This modifier is useful for scroll views where items are prepended to the head of the view instead of the
  /// typical tail. For example, a reverse chronologic list of events where the most recent event is shown at the
  /// head. This modifier ensures the scroll position is maintained, as items are prepended.
  ///
  /// This modifier requires a maintainer object that inherits from `PrependScrollPositionMaintainer`. In a typical
  /// setup, the view model of this scroll view should inherit from that class.
  ///
  /// - Important: The content of this scroll view must not use a lazy stack. Instead only eager stacks such as
  /// `VStack` and `HStack` are supported. Lazy stacks are not supported. Because items in a lazy stack do not report
  /// their frames until they appear. This makes it too late causing the scroll view content to be pushed down before
  /// this modifier can adjust it.
  ///
  /// Each item in the scroll view must be modified with the `trackItemFrame` modifier in order for the scroll
  /// position to be maintained.
  ///
  /// The scroll view must only support a single scrolling axis. Multi-axis scroll views should not use this modifier.
  ///
  /// - Parameters:
  ///   - onPrepend: The publisher that emits IDs of items that are prepended.
  ///   - maintainer: The `PrependScrollPositionMaintainer` object. This is typically the view model of this view.
  ///   - axis: The single axis this scroll supports. This defaults to `vertical`.
  ///   - itemSpacing: The spacing between items in the scroll view. This should be the same value given to the
  ///   `VStack` or `HStack` of this scroll view. This defaults to `0`.
  public func maintainScrollPosition<PrependPublisher: Publisher>(
    onPrepend: PrependPublisher,
    using maintainer: PrependScrollPositionMaintainer,
    axis: Axis = .vertical,
    itemSpacing: CGFloat = 0,
    coordinateNamespace: String
  ) -> some View where PrependPublisher.Output == String, PrependPublisher.Failure == Never {
    onItemsFrameChange(in: coordinateNamespace, maintainer.itemsFrameDidChange)
      .introspectScrollView { uiScrollView in
        maintainer.scrollView = uiScrollView
      }
      .onAppear {
        maintainer.axis = axis
        maintainer.itemSpacing = itemSpacing
      }
      .onReceive(onPrepend) { prependedItemId in
        // Explicitly determine item IDs that are prepended. Because newly added item frames origin does not reflect
        // their position in content offset, there is not reliable way to implicitly determine if a frame is prepended.
        maintainer.prependedItemIds.insert(prependedItemId)
      }
  }
}

/// The base implementation of a utility object that helps maintain the scroll position as items are prepended.
///
/// This implementation can be used in conjunction with the `ScrollView` modifier `maintainScrollPositionOnPrepend`.
/// Generally the view model of the scroll view should inherit from this class to receive the scroll position
/// maintaining implementation for free.
///
/// This object also exposes other helpful utilities such as the scroll view's content offset that can be used to
/// perform other view operations on the scroll view.
open class PrependScrollPositionMaintainer {
  fileprivate var scrollView: UIScrollView?
  fileprivate var axis = Axis.vertical
  fileprivate var itemSpacing = 0.0
  fileprivate var prependedItemIds = Set<String>()

  // This is internal for unit testing.
  private var itemFrames = [String: CGRect]()

  /// Retrieve the frame of the item identified by the given ID.
  ///
  /// - Parameters:
  ///   - itemId: The ID the item is identified with.
  /// - Returns: The frame of the item if there is an item identified by the given ID.
  public final func itemFrame(for itemId: String) -> CGRect? {
    itemFrames[itemId]
  }
}

// MARK: - Maintain Scroll Position on Prepend

extension PrependScrollPositionMaintainer {
  // This is internal for unit testing.
  func itemsFrameDidChange(_ newItemFrames: [String: CGRect]) {
    for (key, frame) in newItemFrames {
      if itemFrames[key] == nil {
        itemFrames[key] = frame

        // Only update content offset when a new frame has been added to the scroll view and its ID has been
        // identified as a prepend item.
        if prependedItemIds.remove(key) != nil {
          updateContentOffsetOnPrependedFrame(frame)
        }
      }
    }
  }

  private func updateContentOffsetOnPrependedFrame(_ frame: CGRect) {
    guard let scrollView = scrollView else {
      return
    }

    var updatedContentOffset = scrollView.contentOffset
    switch axis {
    case .horizontal:
      updatedContentOffset.x += (frame.width + itemSpacing)
    default:
      updatedContentOffset.y += (frame.height + itemSpacing)
    }

    scrollView.setContentOffset(updatedContentOffset, animated: false)
  }
}

#if DEBUG
  class MaintainScrollPositionOnPrependPreviewViewModel: PrependScrollPositionMaintainer, ObservableObject {
    @Published var items = [90, 91, 92, 93, 94, 95, 96, 97, 98, 99]
    @Published var prependItemId = "90"
    @Published var timer: Timer?

    func startInserting() {
      timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
        if let first = self.items.first {
          let item = first - 1
          self.items.insert(item, at: 0)
          self.prependItemId = "\(item)"
        }
      }
    }

    func stopInserting() {
      timer?.invalidate()
      timer = nil
    }
  }

  struct MaintainScrollPositionOnPrependPreview: View {
    private static let coordinateNamespace = "MaintainScrollPositionOnPrependPreview"
    @StateObject private var viewModel = MaintainScrollPositionOnPrependPreviewViewModel()

    var body: some View {
      ScrollView(.vertical, showsIndicators: true) {
        VStack(alignment: .center, spacing: 4) {
          ForEach(viewModel.items) { item in
            Button("\(item) \(viewModel.timer == nil ? "Start" : "Stop") Inserting") {
              if viewModel.timer == nil {
                viewModel.startInserting()
              } else {
                viewModel.stopInserting()
              }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .foregroundColor(Color.white)
            .font(Font.system(size: 24).bold())
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color.red)
            )
            .padding(12)
            .trackItemFrame(itemId: "\(item)", in: MaintainScrollPositionOnPrependPreview.coordinateNamespace)
          }
        }
      }
      .maintainScrollPosition(
        onPrepend: viewModel.$prependItemId,
        using: viewModel,
        axis: .vertical,
        itemSpacing: 4,
        coordinateNamespace: MaintainScrollPositionOnPrependPreview.coordinateNamespace
      )
    }
  }

  struct MaintainScrollPositionOnPrependPreviews: PreviewProvider {
    static var previews: some View {
      MaintainScrollPositionOnPrependPreview()
    }
  }
#endif
