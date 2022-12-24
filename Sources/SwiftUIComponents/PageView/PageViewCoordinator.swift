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
import UIKit

public class PageViewCoordinator: NSObject {
  private let pageViewControllers: [UIViewController]
  private let selection: Binding<Int>?
  private let willTransitionTo: (([Int]) -> Void)?
  private let didTransitionTo: (([Int]) -> Void)?

  init(
    pages: [AnyView],
    selection: Binding<Int>? = nil,
    willTransitionTo: (([Int]) -> Void)? = nil,
    didTransitionTo: (([Int]) -> Void)? = nil
  ) {
    self.pageViewControllers = pages.map(UIHostingController.init)
    self.selection = selection
    self.willTransitionTo = willTransitionTo
    self.didTransitionTo = didTransitionTo
  }
}

// MARK: - UIPageViewControllerDataSource

extension PageViewCoordinator: UIPageViewControllerDataSource {
  public func pageViewController(
    _ pageViewController: UIPageViewController,
    viewControllerBefore viewController: UIViewController
  ) -> UIViewController? {
    guard let index = pageViewControllers.firstIndex(of: viewController), index > 0 else {
      return nil
    }

    return pageViewControllers[index - 1]
  }

  public func pageViewController(
    _ pageViewController: UIPageViewController,
    viewControllerAfter viewController: UIViewController
  ) -> UIViewController? {
    guard let index = pageViewControllers.firstIndex(of: viewController), index < pageViewControllers.count - 1 else {
      return nil
    }

    return pageViewControllers[index + 1]
  }
}

// MARK: - UIPageViewControllerDelegate

extension PageViewCoordinator: UIPageViewControllerDelegate {
  public func pageViewController(
    _ pageViewController: UIPageViewController,
    willTransitionTo pendingViewControllers: [UIViewController]
  ) {
    let indices = pendingViewControllers
      .map(pageViewControllers.firstIndex)
      .compactMap { index in
        if let index = index {
          return Int(index)
        }
        return nil
      }
    willTransitionTo?(indices)
  }

  public func pageViewController(
    _ pageViewController: UIPageViewController,
    didFinishAnimating finished: Bool,
    previousViewControllers: [UIViewController],
    transitionCompleted completed: Bool
  ) {
    guard let currentViewControllers = pageViewController.viewControllers else {
      return
    }

    // Notify.
    let indices = currentViewControllers
      .map(pageViewControllers.firstIndex)
      .compactMap { index in
        if let index = index {
          return Int(index)
        }
        return nil
      }
    didTransitionTo?(indices)

    // Update programatic selection binding.
    if let index = indices.first {
      selection?.wrappedValue = index
    }
  }
}

// MARK: - Get and Set Current Page

extension PageViewCoordinator {
  func setPage(to targetIndex: Int, pageViewController: UIPageViewController, animated: Bool) {
    let currentPageIndex = currentPageIndex(pageViewController: pageViewController)
    // Determine paging based on current page index.
    let direction: UIPageViewController.NavigationDirection
    if let currentPageIndex = currentPageIndex {
      if targetIndex > currentPageIndex {
        direction = .forward
      } else if targetIndex < currentPageIndex {
        direction = .reverse
      } else {
        return
      }
    } else {
      direction = .forward
    }

    pageViewController.setViewControllers(
      [pageViewControllers[targetIndex]],
      direction: direction,
      animated: animated
    )
  }

  func currentPageIndex(pageViewController: UIPageViewController) -> Int? {
    guard let currentViewController = pageViewController.viewControllers?.first else {
      return nil
    }
    return pageViewControllers.firstIndex(of: currentViewController)
  }
}
