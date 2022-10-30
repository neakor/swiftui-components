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

/// The loader that loads items to be appended to the end of a `DequeScrollView`.
///
/// This loader is triggered to load more items to be appended to the end of a `DequeScrollView`. This is triggered
/// when the deque has been scrolled to review the last item, therefore more should be loaded to provide the proverbial
/// infinite scrolling.
public protocol DequeAppendItemsLoader: AnyObject {
  /// Load more items to be appended to the `DequeScrollView`.
  ///
  /// - Note: Once loading completes, the update set of items should be provided to the view model via the `setItems`
  /// function.
  ///
  /// - Parameters:
  ///   - completion: The closure to be invoked when the loading completes. Pass in `true` to the closure if there
  ///   are more items that can be loaded for appending. `false` if the end of the deque data has been reached.
  /// - Returns: The cancellable resulted from the loading operation.
  func loadItemsToAppend(completion: @escaping (Bool) -> Void) -> AnyCancellable
}

/// The base implementation of the view model of a `DequeScrollView`.
///
/// This implementation provides the logic of maintaining scroll position when items are prepended to the
/// corresponding `DequeScrollView`, invoking the `DequeAppendItemsLoader` when the scroll view scrolls and reveals
/// the last item, and showing the prepended items pill when items are prepended but the scroll view is scrolled
/// below them.
///
/// This implementation should be the superclass of view models that provide for views of `DequeScrollView`. Each item
/// provided by the view model must be `Identifiable` and `Equatable`. The `ID` of an item must be a `String`.
open class DequeViewModel<Item: Identifiable & Equatable>: NSObject, ObservableObject, UIScrollViewDelegate
  where Item.ID == String
{
  /// The state of the items.
  public enum ItemsState {
    case loading
    case value([Item])
    case error
  }

  /// The loader used to load items to append, as the scroll view scrolls to reveal the last item. This property is
  /// weakily held to avoid any potential retain cycles.
  public weak var appendItemsLoader: DequeAppendItemsLoader?
  /// The items that are currently presented in the corresponding `DequeScrollView`.
  @Published public private(set) var itemsState = ItemsState.loading
  @Published private(set) var prependedItemId = ""
  @Published private(set) var prependedItemsPillIsShown = false

  let prependScrollPositionMaintainer: PrependScrollPositionMaintainer
  var dequeFrame = CGRect()

  private let hasPrependedItemsPill: Bool
  private var isLoadingMoreItemsToAppend = false
  private var canLoadMoreItemsToAppend = true
  private var currentContentOffset = CGPoint()
  private var loadAppendItemsCancellable: AnyCancellable?

  /// Initialize.
  ///
  /// - Parameters:
  ///    - hasPrependedItemsPill: `true` if the corresponding `DequeScrollView` has a pill to indicate items have
  ///    been prepended to the deque.
  public init(hasPrependedItemsPill: Bool) {
    self.prependScrollPositionMaintainer = PrependScrollPositionMaintainer()
    self.hasPrependedItemsPill = hasPrependedItemsPill
  }

  // Objective-C function cannot be placed in an extension.
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    currentContentOffset = scrollView.contentOffset

    // Hide new items pill if scrolling revealed the first item.
    if prependedItemsPillIsShown, isFirstItemShown() {
      withAnimation {
        prependedItemsPillIsShown = false
      }
    }

    loadMoreItemsToAppendOnLastItemShown()
  }
}

// MARK: - Update items

extension DequeViewModel {
  /// Set the items to be provided to the corresponding `DequeScrollView` for display.
  ///
  /// - Important: This function does not provide any sorting of items. All sorting should be performed before
  /// invoking this function. The view model makes no assumption about how items should be sorted. The corresponding
  /// `DequeScrollView` presents items in the order of the given array.
  ///
  ///
  /// - Parameters:
  ///   - newItems: The items to be presented by the corresponding `DequeScrollView`.
  public func setItemsState(_ newState: ItemsState) {
    switch newState {
    case .loading, .error:
      itemsState = newState
    case let .value(newItems):
      let existingItems: [Item]
      switch itemsState {
      case .loading, .error:
        existingItems = []
      case let .value(items):
        existingItems = items
      }

      setItemsValueState(newItems: newItems, existingItems: existingItems)
    }
  }

  private func setItemsValueState(newItems: [Item], existingItems: [Item]) {
    // Determine items that are ahead of existing ones to update prepend data and jump pill.
    if let existingLatestItem = existingItems.first,
       let existingLatestItemIndexInNewItems = newItems.firstIndex(of: existingLatestItem)
    {
      let aheadItems = newItems.prefix(upTo: existingLatestItemIndexInNewItems)
      if !aheadItems.isEmpty {
        showPrependedItemsPill()
      }

      aheadItems.forEach { prependedItemId = $0.id }
    }

    itemsState = .value(newItems)
  }
}

// MARK: - Prepended items pill

extension DequeViewModel {
  private func showPrependedItemsPill() {
    guard hasPrependedItemsPill, !prependedItemsPillIsShown, !isFirstItemShown() else {
      return
    }

    withAnimation {
      prependedItemsPillIsShown = true
    }
  }

  private func isFirstItemShown() -> Bool {
    guard
      case let .value(items) = itemsState,
      let firstItem = items.first,
      let firstItemFrame = prependScrollPositionMaintainer.itemFrame(for: firstItem.id)
    else {
      return false
    }
    return currentContentOffset.y < firstItemFrame.height
  }
}

// MARK: - Load appended items

extension DequeViewModel {
  /// Load more items to append if the last item is shown.
  ///
  /// - Note: This function only invokes the loader if the previous invocation has determined that there are more
  /// items to load, there isn't a loading in already in progress and the last item has been shown.
  public final func loadMoreItemsToAppendOnLastItemShown() {
    guard isLastItemShown() else {
      return
    }

    loadMoreItemsToAppend()
  }

  func loadMoreItemsToAppend() {
    guard let appendItemsLoader = appendItemsLoader, !isLoadingMoreItemsToAppend, canLoadMoreItemsToAppend else {
      return
    }

    isLoadingMoreItemsToAppend = true
    loadAppendItemsCancellable?.cancel()
    loadAppendItemsCancellable = appendItemsLoader.loadItemsToAppend { [weak self] canLoadMoreItemsToAppend in
      guard let self = self else {
        return
      }

      self.isLoadingMoreItemsToAppend = false
      self.canLoadMoreItemsToAppend = canLoadMoreItemsToAppend

      // Repeatedly load more append items since each attempt may not fill up the entire deque.
      self.loadMoreItemsToAppendOnLastItemShown()
    }
  }

  func viewDidDisappear() {
    loadAppendItemsCancellable?.cancel()
    loadAppendItemsCancellable = nil
  }

  private func isLastItemShown() -> Bool {
    guard case let .value(items) = itemsState else {
      return false
    }

    let allItemsHeight = items
      .compactMap { prependScrollPositionMaintainer.itemFrame(for: $0.id) }
      .reduce(into: 0.0) { partialResult, itemFrame in
        partialResult += itemFrame.height
      }
    var lastItemHeight: CGFloat = 0.0
    if let lastItem = items.last {
      lastItemHeight = prependScrollPositionMaintainer.itemFrame(for: lastItem.id)?.height ?? 0
    }
    let tillLastItemHeight = allItemsHeight - lastItemHeight
    return abs(currentContentOffset.y) + dequeFrame.maxY >= tillLastItemHeight
  }
}
