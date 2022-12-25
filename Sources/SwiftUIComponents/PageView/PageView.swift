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

/// A SwiftUI representation of `UIPageViewController`.
///
/// For details on style customization, please see `UIPageViewController`. The customization values supported in this
/// SwiftUI view directly maps to their corresponding the UIKit values.
///
/// The individual page SwiftUI views provided to this container view must be type-erased `AnyView`. This allows each
/// page to vary in its composition while can still be shown in the container along other pages.
///
/// The parent view can supply closures to this container view to get notified when a gesture based navigation occurs
/// and completes. A binding of page index can also be supplied to control paging programmatically.
public struct PageView: UIViewControllerRepresentable {
  public enum TransitionStyle {
    case pageCurl
    case scroll(interPageSpacing: CGFloat)
  }

  public enum NavigationOrientation {
    case horizontal
    case vertical
  }

  public enum SpineLocation {
    case none
    case leading
    case trailing
  }

  public let transitionStyle: TransitionStyle
  public let navigationOrientation: NavigationOrientation
  public let spineLocation: SpineLocation
  private let initialPageIndex: Int
  private let pages: [AnyView]
  private let selection: Binding<Int>?
  private let willTransitionTo: (([Int]) -> Void)?
  private let didTransitionTo: (([Int]) -> Void)?

  /// Initializer.
  ///
  /// - Parameters:
  ///   - transitionStyle: The transition style to use for paging.
  ///   - navigationOrientation: The paging orientation.
  ///   - spineLocation: Spine location to use for page curl transition. This value is not used if the transition style is `scroll`.
  ///   - initialPageIndex: The initial page index when the view is first shown.
  ///   - pages: The list of type-erased views to use as pages.
  ///   - selection: The binding that can be used to programmatically page the content.
  ///   - willTransitionTo: A closure invoked right before a gesture initiated paging occurs.
  ///   - didTransitionTo: A closure invoked after a gesture initiated paging completes.
  public init(
    transitionStyle: TransitionStyle = .scroll(interPageSpacing: 0),
    navigationOrientation: NavigationOrientation,
    spineLocation: SpineLocation = .leading,
    initialPageIndex: Int = 0,
    // Type erase at the callsite to allow each page at the callsite to vary in composition. Otherwise each page at
    // the callsite must have the same SwiftUI modifiers applied.
    pages: [AnyView],
    selection: Binding<Int>? = nil,
    willTransitionTo: (([Int]) -> Void)? = nil,
    didTransitionTo: (([Int]) -> Void)? = nil
  ) {
    self.transitionStyle = transitionStyle
    self.navigationOrientation = navigationOrientation
    self.spineLocation = spineLocation
    self.initialPageIndex = initialPageIndex
    self.pages = pages
    self.selection = selection
    self.willTransitionTo = willTransitionTo
    self.didTransitionTo = didTransitionTo
  }

  public func makeCoordinator() -> PageViewCoordinator {
    PageViewCoordinator(
      pages: pages,
      selection: selection,
      willTransitionTo: willTransitionTo,
      didTransitionTo: didTransitionTo
    )
  }

  public func makeUIViewController(context: Context) -> UIPageViewController {
    var options = [UIPageViewController.OptionsKey: Any]()
    switch transitionStyle {
    case .pageCurl:
      options[UIPageViewController.OptionsKey.spineLocation] = spineLocation.uiKitValue
    case let .scroll(value):
      options[UIPageViewController.OptionsKey.interPageSpacing] = NSNumber(value: value)
    }
    let pageViewController = UIPageViewController(
      transitionStyle: transitionStyle.uiKitValue,
      navigationOrientation: navigationOrientation.uiKitValue,
      options: options
    )
    pageViewController.view.backgroundColor = UIColor.clear

    // Set data source to allow gesture based navigation.
    pageViewController.dataSource = context.coordinator
    // Set delegate to support programmatic paging.
    pageViewController.delegate = context.coordinator

    context.coordinator.setPage(to: initialPageIndex, pageViewController: pageViewController, animated: false)

    return pageViewController
  }

  public func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
    // When selection binding updates, set the page to that index.
    guard let targetIndex = selection?.wrappedValue, targetIndex >= 0, targetIndex < pages.count else {
      return
    }

    context.coordinator.setPage(to: targetIndex, pageViewController: pageViewController, animated: true)
  }
}

// MARK: - UIKit Value Conversions

extension PageView.TransitionStyle {
  fileprivate var uiKitValue: UIPageViewController.TransitionStyle {
    switch self {
    case .pageCurl:
      return .pageCurl
    case .scroll:
      return .scroll
    }
  }
}

extension PageView.NavigationOrientation {
  fileprivate var uiKitValue: UIPageViewController.NavigationOrientation {
    switch self {
    case .horizontal:
      return .horizontal
    case .vertical:
      return .vertical
    }
  }
}

extension PageView.SpineLocation {
  fileprivate var uiKitValue: NSNumber {
    let value: UIPageViewController.SpineLocation
    switch self {
    case .none:
      value = .none
    case .leading:
      value = .min
    case .trailing:
      value = .max
    }
    return NSNumber(value: value.rawValue)
  }
}

#if DEBUG
struct PageViewPreviewProvider: PreviewProvider {
  static var previews: some View {
    SelectablePageView(
      transitionStyle: .scroll(interPageSpacing: 16),
      navigationOrientation: .horizontal,
      initialPageIndex: 0
    )
    .previewDisplayName("Horizontal")

    SelectablePageView(
      transitionStyle: .scroll(interPageSpacing: 16),
      navigationOrientation: .vertical,
      initialPageIndex: 0
    )
    .previewDisplayName("Vertical")

    SelectablePageView(
      transitionStyle: .scroll(interPageSpacing: 0),
      navigationOrientation: .horizontal,
      initialPageIndex: 1
    )
    .previewDisplayName("Non-zero initial index")

    SelectablePageView(
      transitionStyle: .pageCurl,
      navigationOrientation: .horizontal,
      initialPageIndex: 0
    )
    .previewDisplayName("Curl")
  }
}

struct SelectablePageView: View {
  private let transitionStyle: PageView.TransitionStyle
  private let navigationOrientation: PageView.NavigationOrientation
  private let initialPageIndex: Int
  @State private var selection: Int

  init(
    transitionStyle: PageView.TransitionStyle,
    navigationOrientation: PageView.NavigationOrientation,
    initialPageIndex: Int
  ) {
    self.transitionStyle = transitionStyle
    self.navigationOrientation = navigationOrientation
    self.initialPageIndex = initialPageIndex
    self.selection = initialPageIndex
  }

  var body: some View {
    VStack(alignment: .center, spacing: 32) {
      Text("Current selection \(selection)")
      Button("Increment") {
        guard selection < 2 else {
          return
        }
        selection += 1
      }
      Button("Decrement") {
        guard selection > 0 else {
          return
        }
        selection -= 1
      }

      PageView(
        transitionStyle: transitionStyle,
        navigationOrientation: navigationOrientation,
        initialPageIndex: initialPageIndex,
        pages: colorBlocks,
        selection: $selection
      )
    }
  }

  private var colorBlocks: [AnyView] {
    [
      colorBlock(of: 0, color: .red),
      colorBlock(of: 1, color: .green),
      colorBlock(of: 2, color: .blue),
    ]
  }

  private func colorBlock(of index: Int, color: Color) -> AnyView {
    AnyView(
      Text("Page \(index)")
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(color)
    )
  }
}
#endif
