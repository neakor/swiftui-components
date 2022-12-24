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

/// Handler used to perform snap scrolling on a `ScrollView`.
///
/// This handler can only perform snapping of scroll views whose items are all of the same size in the scrolling axis.
///
/// This object must be retained by the parent view. Generally this object can be either created as a `StateObject`
/// within a view or as a property of a view's view model.
///
/// The handler can be configured to perform different types of snapping behavior. Please see `Behavior` for details.
public class ScrollViewSnapHandler: NSObject, ObservableObject, UIScrollViewDelegate {
  /// The axis of the scroll view.
  public enum Axis {
    case x
    case y
  }

  /// The types of snapping behavior.
  public enum Behavior {
    /// Allowing multiple items to be scrolled by and eventually snapped to a final item in a single scrolling action.
    case allowMultiItems
    /// Only allow a single item to be scrolled by with a single scrolling action. A default scrolling speed threshold
    /// is used.
    case singleItem
    /// Only allow a single item to be scrolled by with a single scrolling action with the specified custom scrolling
    /// speed threshold.
    case singleItemCustomThresholdSpeed(thresholdSpeed: CGFloat)
  }

  private enum ConsolidatedBehavior {
    case allowMultiItems
    case singleItem(thresholdSpeed: CGFloat)
  }

  private let behavior: ConsolidatedBehavior
  private let axis: Axis
  private let itemSize: CGFloat
  private let thresholdItemScrollDistance: CGFloat
  private var scrollViewLeadingOffset: CGPoint?
  private var beginDraggingOffset = CGPoint()

  /// Initializer.
  ///
  /// - Parameters:
  ///   - behavior: The snapping behavior.
  ///   - axis: The scroll view's scroll axis.
  ///   - itemSize: The size of each item in the scroll view.
  ///   - thresholdItemSizePercentage: The percentage of an item must be scrolled past to initiate snapping to the
  ///   next item.
  public init(
    behavior: Behavior,
    axis: Axis,
    itemSize: CGFloat,
    thresholdItemSizePercentage: CGFloat = 0.5
  ) {
    switch behavior {
    case .allowMultiItems:
      self.behavior = .allowMultiItems
    case .singleItem:
      self.behavior = .singleItem(thresholdSpeed: 0.5)
    case let .singleItemCustomThresholdSpeed(thresholdSpeed):
      self.behavior = .singleItem(thresholdSpeed: thresholdSpeed)
    }

    self.axis = axis
    self.itemSize = itemSize
    thresholdItemScrollDistance = itemSize * thresholdItemSizePercentage
  }

  public final func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    if scrollViewLeadingOffset == nil {
      scrollViewLeadingOffset = scrollView.contentOffset
    }
    beginDraggingOffset = scrollView.contentOffset
  }

  public final func scrollViewWillEndDragging(
    _ scrollView: UIScrollView,
    withVelocity velocity: CGPoint,
    targetContentOffset: UnsafeMutablePointer<CGPoint>
  ) {
    targetContentOffset.pointee = targetSnapContentOffset(
      scrollTargetContentOffset: targetContentOffset.pointee,
      scrollVelocity: velocity
    )
  }

  private func targetSnapContentOffset(scrollTargetContentOffset: CGPoint, scrollVelocity: CGPoint) -> CGPoint {
    guard let scrollViewLeadingOffset = scrollViewLeadingOffset else {
      return beginDraggingOffset
    }

    let targetItemCount = targetItemCount(
      scrollTargetContentOffset: scrollTargetContentOffset,
      scrollVelocity: scrollVelocity,
      scrollViewLeadingOffset: scrollViewLeadingOffset
    )
    let snapScrollTargetOffset = CGFloat(targetItemCount) * itemSize + scrollViewLeadingOffset.componentValue(in: axis)
    return scrollTargetContentOffset.setValue(snapScrollTargetOffset, in: axis)
  }

  private func targetItemCount(
    scrollTargetContentOffset: CGPoint,
    scrollVelocity: CGPoint,
    scrollViewLeadingOffset: CGPoint
  ) -> Int {
    // Adjust target content offset to include the leading offset. This reflects where the target is relative to the
    // actual content, with the first content placed at offset 0. In other words, this is the target content offset
    // in the actual content's coordinate space.
    let adjustedTargetContentOffset = scrollTargetContentOffset.componentValue(in: axis) +
    abs(scrollViewLeadingOffset.componentValue(in: axis))

    switch behavior {
    case .allowMultiItems:
      return Int(((adjustedTargetContentOffset - thresholdItemScrollDistance) / itemSize).rounded(.up))
    case let .singleItem(thresholdSpeed):
      let adjustedBeginContentOffset = beginDraggingOffset.componentValue(in: axis) +
      abs(scrollViewLeadingOffset.componentValue(in: axis))
      let beginItemCount = Int(adjustedBeginContentOffset / itemSize)

      let targetScrollDistance = abs(adjustedTargetContentOffset - adjustedBeginContentOffset)
      guard targetScrollDistance > thresholdItemScrollDistance ||
              abs(scrollVelocity.componentValue(in: axis)) > thresholdSpeed else {
        return beginItemCount
      }

      if adjustedTargetContentOffset > adjustedBeginContentOffset {
        return beginItemCount + 1
      } else {
        return max(beginItemCount - 1, 0)
      }
    }
  }
}

extension CGPoint {
  fileprivate func setValue(_ value: CGFloat, in axis: ScrollViewSnapHandler.Axis) -> CGPoint {
    switch axis {
    case .x:
      return CGPoint(x: value, y: y)
    case .y:
      return CGPoint(x: x, y: value)
    }
  }

  fileprivate func componentValue(in axis: ScrollViewSnapHandler.Axis) -> CGFloat {
    switch axis {
    case .x:
      return x
    case .y:
      return y
    }
  }
}
