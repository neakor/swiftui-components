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
import SwiftUI

/// The `RefreshControl` is actually an `UIScrollView` with an `UIRefreshControl` attached. The content offset of this
/// refresh control's scroll view is synchronized to an external publisher via the `RefreshControlCoordinator`.
/// Typically this publisher receives content offset values from a SwiftUI `ScrollView` that contains the actual
/// content. This synchronizes the refresh control's scroll view's content offset to that of the external SwiftUI
/// `ScrollView`. When the refresh control's scroll view's offset is updated beyond its edge, the attached
/// `UIRefreshControl` shows. When the offset moves pass a threshold, the `UIRefreshControl` is manually triggered to
/// animate, and the refresh action closure is invoked.
struct RefreshControl {
  // This value is obtained from the default UIKit refresh control trigger offset.
  static let height = 120.0

  let sourceContentOffset: AnyPublisher<CGPoint, Never>
  // Since refresh is triggered via content offset changes, the source content scroll view may not want to always
  // trigger new refreshes every time the scrolling passes the threshold. For example, in a single dragging session
  // only a single refresh should be triggered.
  let shouldRefresh: () -> Bool
  let refreshAction: (@escaping () -> Void) -> Void
}

// MARK: - UIViewRepresentable

extension RefreshControl: UIViewRepresentable {
  func makeCoordinator() -> RefreshControlCoordinator {
    RefreshControlCoordinator(
      sourceContentOffset: sourceContentOffset,
      shouldRefresh: shouldRefresh,
      refreshAction: refreshAction
    )
  }

  func makeUIView(context: Context) -> UIScrollView {
    let scrollView = UIScrollView()

    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false

    // Attach UIRefreshControl.
    let refreshControl = UIRefreshControl()
    refreshControl.addTarget(
      context.coordinator,
      action: #selector(RefreshControlCoordinator.refreshControlDidFire),
      for: .valueChanged
    )
    scrollView.refreshControl = refreshControl

    // Use the coordinate to synchronize the scroll view's content offset to the view model's.
    context.coordinator.synchronizeContentOffset(to: scrollView)

    return scrollView
  }

  func updateUIView(_ uiView: UIScrollView, context: Context) {}
}

// MARK: - RefreshControlCoordinator

// This class needs to be internal due to conformance of UIViewRepresentable.
class RefreshControlCoordinator {
  private let sourceContentOffset: AnyPublisher<CGPoint, Never>
  private let shouldRefresh: () -> Bool
  private let refreshAction: (@escaping () -> Void) -> Void

  private var contentOffsetSynchronizationCancellable: Cancellable?

  init(
    sourceContentOffset: AnyPublisher<CGPoint, Never>,
    shouldRefresh: @escaping () -> Bool,
    refreshAction: @escaping (@escaping () -> Void) -> Void
  ) {
    self.sourceContentOffset = sourceContentOffset
    self.shouldRefresh = shouldRefresh
    self.refreshAction = refreshAction
  }

  @objc fileprivate func refreshControlDidFire(_ refreshControl: UIRefreshControl) {
    performRefresh(refreshControl: refreshControl)
  }

  fileprivate func synchronizeContentOffset(to refreshControlScrollView: UIScrollView) {
    contentOffsetSynchronizationCancellable = sourceContentOffset
      .receive(on: DispatchQueue.main)
      .sink { [weak refreshControlScrollView, weak self] contentOffset in
        guard let refreshControlScrollView = refreshControlScrollView, let self = self else {
          return
        }

        // The content offset needs to be inverted to UIKit.
        refreshControlScrollView.contentOffset = -contentOffset

        if self.shouldTriggerRefresh(refreshControlScrollView) {
          self.performRefresh(refreshControl: refreshControlScrollView.refreshControl)
        }
      }
  }

  private func shouldTriggerRefresh(_ refreshControlScrollView: UIScrollView) -> Bool {
    // Ensure it is not already refreshing since this is invoked during content offset updates which can be high
    // frequency.
    refreshControlScrollView.contentOffset.y < -RefreshControl.height &&
      refreshControlScrollView.refreshControl?.isRefreshing == false &&
      shouldRefresh()
  }

  private func performRefresh(refreshControl: UIRefreshControl?) {
    refreshControl?.beginRefreshing()

    refreshAction {
      refreshControl?.endRefreshing()
    }
  }
}
