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

/// A SwiftUI scroll view that has an attached refresh control.
///
/// This type is implemented to support refresh control for a SwiftUI scroll view, without using a `List`.
public struct RefreshableScrollView<Content: View>: View {
  private let axes: Axis.Set
  private let showsIndicators: Bool
  private let refreshAction: (@escaping () -> Void) -> Void
  private let content: Content

  // Disable weak_delegate rule since this is managed by SwiftUI.
  // swiftlint:disable:next weak_delegate
  @StateObject private var scrollViewDelegate = RefreshableScrollViewDelegate()
  @StateObject private var observableContentOffset = ObservableContentOffset()

  public init(
    _ axes: Axis.Set = .vertical,
    showsIndicators: Bool = true,
    refreshAction: @escaping (@escaping () -> Void) -> Void,
    @ViewBuilder contentBuilder: @escaping () -> Content
  ) {
    self.axes = axes
    self.showsIndicators = showsIndicators
    self.refreshAction = refreshAction
    self.content = contentBuilder()
  }

  // The implementation strategy is to put a UIKit UIScrollView with an attached UIRefreshControl behind a SwiftUI
  // scroll that actually contains the content. The UIKit scroll view's content offset is synchronized to that of the
  // SwiftUI scroll view as the user scrolls the content. This allows the UIKit scroll view to trigger its refresh
  // control when the scrolling passes a threshold. During the refreshing, the SwiftUI scroll view's content offset
  // is manually updated to reveal the refresh control.
  // Instead of updating the content offset to reveal the refresh control, an alternative attempted is to use a
  // transparent view inserted above the content SwiftUI scroll view when refreshing is triggered. This however creates
  // a jarring experience when the gap view is first shown. It pushes down the content with a "jump". Then the content
  // decelerates back to the top.
  public var body: some View {
    ZStack {
      RefreshControl(
        sourceContentOffset: observableContentOffset.$value.eraseToAnyPublisher(),
        shouldRefresh: { scrollViewDelegate.shouldRefresh },
        refreshAction: { completion in
          scrollViewDelegate.isRefreshing = true
          refreshAction {
            scrollViewDelegate.isRefreshing = false
            completion()
          }
        }
      )

      ScrollView(axes, showsIndicators: showsIndicators) {
        content.trackContentOffset()
      }
      .onContentOffsetChange { contentOffset in
        observableContentOffset.value = contentOffset
      }
      .introspectScrollView { uiScrollView in
        // Use a delegate to update the content offset to reveal the refresh control when refreshing.
        if uiScrollView.delegate !== scrollViewDelegate {
          uiScrollView.delegate = scrollViewDelegate
          scrollViewDelegate.initialContentOffset = uiScrollView.contentOffset
        }
      }
    }
  }
}

/// An observable object to allow publishing the SwiftUI scroll view's content offset to the UIKit refresh control.
/// This class conforms to the `ObservableObject` protocol to allow it to be instantiated by the SwiftUI scroll view,
/// and transformed into a publisher to send to the UIKit scroll view.
private class ObservableContentOffset: ObservableObject {
  @Published fileprivate var value = CGPoint()
}

/// The delegate of a SwiftUI `ScrollView` that contains the actual content.
///
/// The primary role of this delegate is to set the SwiftUI `ScrollView`'s content offset to reveal the refresh
/// control spinner when the content is being refreshed.
///
/// This class conforms to the `ObservableObject` protocol to allow it to be instantiated by the SwiftUI scroll view.
private class RefreshableScrollViewDelegate: NSObject, UIScrollViewDelegate, ObservableObject {
  fileprivate var initialContentOffset: CGPoint?
  fileprivate var shouldRefresh = false
  fileprivate var isRefreshing = false {
    didSet {
      if isRefreshing {
        // Once a refresh starts, do not allow more refreshes within the same dragging session.
        shouldRefresh = false
      } else {
        // When refreshing stops, if the content scroll view is still at the refresh control's offset, reset it to its
        // initial offset. This case occurs when there is no content in the content scroll view or the content didn't
        // change. When the content changes, SwiftUI automatically resets the offset.
        if let initialContentOffset = initialContentOffset,
           overrideContentOffsetScrollView?.contentOffset.y == -RefreshControl.height
        {
          overrideContentOffsetScrollView?.setContentOffset(initialContentOffset, animated: false)
        }
      }
    }
  }

  private var overrideContentOffsetOnDecelerating = false
  private var overrideContentOffsetScrollView: UIScrollView?

  fileprivate func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    // If a new dragging session started, allow refreshing if it's not already refreshing.
    shouldRefresh = !isRefreshing
  }

  fileprivate func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
    // Only override content offset to reveal refresh control when the content is decelerating after a release. This
    // prevents this from getting updated all the time as the user is simply dragging the content.
    if overrideContentOffsetOnDecelerating {
      scrollView.setContentOffset(CGPoint(x: 0, y: -RefreshControl.height), animated: true)
      overrideContentOffsetScrollView = scrollView
      // Only override once. This allows subsequent scrolling during a refresh to not be affected.
      overrideContentOffsetOnDecelerating = false
    }
  }

  func scrollViewWillEndDragging(
    _ scrollView: UIScrollView,
    withVelocity velocity: CGPoint,
    targetContentOffset: UnsafeMutablePointer<CGPoint>
  ) {
    // Override content offset when the scrolling decelerates if it is during a refresh and the original target offset
    // is the top of the content.
    if isRefreshing, targetContentOffset.pointee == initialContentOffset {
      overrideContentOffsetOnDecelerating = true
    }
  }
}

#if DEBUG
  struct RefreshableScrollViewPreviews: PreviewProvider {
    private static let allTexts = ["Hello", "World", "Preview", "RefreshableScrollView"]

    struct AddRemovePreview: View {
      @State private var texts = [String]()
      @State private var isAdding = true

      var body: some View {
        RefreshableScrollView(
          refreshAction: { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
              if isAdding {
                texts.append(RefreshableScrollViewPreviews.allTexts[texts.count])
                if texts.count == RefreshableScrollViewPreviews.allTexts.count {
                  isAdding = false
                }
              } else {
                texts.removeLast()
                if texts.isEmpty {
                  isAdding = true
                }
              }

              completion()
            }
          },
          contentBuilder: {
            VStack {
              ForEach(Array(texts.enumerated()), id: \.offset) { index, text in
                Text(text)
                  .id(text)
                  .padding(16)
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  .if(
                    index % 2 == 0,
                    trueTransform: { textView in
                      textView.background(Color.blue)
                    },
                    falseTransform: { textView in
                      textView.background(Color.red)
                    }
                  )
              }
            }
          }
        )
      }
    }

    struct NoContentPreview: View {
      var body: some View {
        RefreshableScrollView(
          refreshAction: { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: completion)
          },
          contentBuilder: {
            EmptyView()
          }
        )
      }
    }

    struct AddThenInfiniteLoadingPreview: View {
      @State private var texts = [String]()

      var body: some View {
        RefreshableScrollView(
          refreshAction: { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
              texts.append(RefreshableScrollViewPreviews.allTexts[texts.count])
              if texts.count < RefreshableScrollViewPreviews.allTexts.count {
                completion()
              }
            }
          },
          contentBuilder: {
            VStack {
              ForEach(Array(texts.enumerated()), id: \.offset) { index, text in
                Text(text)
                  .id(text)
                  .padding(16)
                  .frame(height: 300)
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  .if(
                    index % 2 == 0,
                    trueTransform: { textView in
                      textView.background(Color.blue)
                    },
                    falseTransform: { textView in
                      textView.background(Color.red)
                    }
                  )
              }
            }
          }
        )
      }
    }

    struct StaticContentPreview: View {
      var body: some View {
        RefreshableScrollView(
          refreshAction: { completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: completion)
          },
          contentBuilder: {
            VStack {
              ForEach(Array(RefreshableScrollViewPreviews.allTexts.enumerated()), id: \.offset) { index, text in
                Text(text)
                  .id(text)
                  .padding(16)
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  .if(
                    index % 2 == 0,
                    trueTransform: { textView in
                      textView.background(Color.blue)
                    },
                    falseTransform: { textView in
                      textView.background(Color.red)
                    }
                  )
              }
            }
          }
        )
      }
    }

    static var previews: some View {
      Group {
        AddRemovePreview()
        AddThenInfiniteLoadingPreview()
        NoContentPreview()
        StaticContentPreview()
      }
    }
  }
#endif
