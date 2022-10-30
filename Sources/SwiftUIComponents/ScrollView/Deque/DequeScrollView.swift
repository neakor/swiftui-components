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

private let dequeScrollViewId = "DequeScrollView.id"
private let dequeScrollViewCoordinateNamespace = "DequeScrollView.coordinateNamespace"
private let dequeScrollViewContentCoordinateNamespace = "DequeScrollView.contentCoordinateNamespace"

/// A scroll view that supports both prepend and append items.
///
/// When items are prepended, this scroll view ensures the current scroll position is maintained. In other words the
/// scroll view's content does not get pushed further after new items are prepended. For example, in a vertically
/// scrolling `DequeScrollView`, after new items are prepended, the content will not be pushed down.
///
/// Items can also be appended to the end of this scroll view. When the existing last item in the scroll view is shown,
/// this view automatically invokes the corresponding view model's `DequeAppendItemsLoader` to load more items. This
/// provides the proverbial infinite scrolling behavior.
///
/// A "pill" view can be optionally configured to present itself when new items are prepended to the deque, yet the
/// deque is scrolled below the new items. Tapping the pill automatically scrolls the content to the most recently
/// prepended item.
///
/// The view model providing items data of this scroll view should typically inherit from the `DequeViewModel` class.
/// That implementation provides all the necessary logic to maintain the behaviors described above.
///
/// The items presented in this scroll view must be `Identifiable` and `Equatable`. The `ID` of an item must
/// be a `String`.
///
/// - Important: Each item view in this scroll view must be modified with the `trackItemFrame(itemId: in:)` modifier
/// in order for the scroll position to be properly maintained during prepend.
///
/// - Note: This scroll view only supports a single scrolling axis. This limitation ensures the scroll position can
/// be properly maintained when items are prepended.
public struct DequeScrollView
<Content: View, PrependedItemsPillLabel: View, Item: Identifiable & Equatable, ViewModel: DequeViewModel<Item>>: View
  where Item.ID == String
{
  @ObservedObject private var viewModel: ViewModel
  private let axis: Axis
  private let showsIndicators: Bool
  private let itemSpacing: CGFloat
  private let prependedItemsPillLabel: PrependedItemsPillLabel?
  private let content: Content

  /// Initialize.
  ///
  /// - Parameters:
  ///   - axis: The single scrolling axis of this scroll view.
  ///   - showsIndicator: `true` if the standard scroll view indicators should be shown.
  ///   - itemSpacing: The spacing between each item in the scroll view.
  ///   - viewModel: The view model providing the items of this view. Generally this should be an instance of a
  ///   subclass of `DequeViewModel`.
  ///   - prependedItemsPillLabel: The label to be used for the pill shown when items are prepended to the deque.
  ///   - content: The content of this scroll view. The closure is given the name of the coordinate namespace that be
  ///   directly passed to the `trackItemFrame(itemId: in:)` modifier, for each of the item's view.
  public init(
    axis: Axis = .vertical,
    showsIndicators: Bool = true,
    itemSpacing: CGFloat = 0,
    viewModel: ViewModel,
    prependedItemsPillLabel: (() -> PrependedItemsPillLabel)? = nil,
    content: (String) -> Content
  ) {
    self.axis = axis
    self.showsIndicators = showsIndicators
    self.itemSpacing = itemSpacing
    self.viewModel = viewModel
    self.prependedItemsPillLabel = prependedItemsPillLabel?()
    self.content = content(dequeScrollViewContentCoordinateNamespace)
  }

  /// The body of the view.
  public var body: some View {
    deque
      // Track the deque itself's frame to allow the view model to determine if the last item shown.
      .trackItemFrame(itemId: dequeScrollViewId, in: dequeScrollViewCoordinateNamespace)
      .onItemsFrameChange(in: dequeScrollViewCoordinateNamespace) { itemFrames in
        if let dequeFrame = itemFrames[dequeScrollViewId] {
          viewModel.dequeFrame = dequeFrame
        }
      }
      .onAppear {
        // Explicitly trigger an initial loading of appended items.
        viewModel.loadMoreItemsToAppend()
      }
      .onDisappear {
        viewModel.viewDidDisappear()
      }
  }

  private var contentScrollView: some View {
    ScrollView(axis.set, showsIndicators: showsIndicators) {
      content
    }
    .maintainScrollPosition(
      onPrepend: viewModel.$prependedItemId,
      using: viewModel.prependScrollPositionMaintainer,
      axis: axis,
      itemSpacing: itemSpacing,
      coordinateNamespace: dequeScrollViewContentCoordinateNamespace
    )
    .introspectScrollView { scrollView in
      scrollView.delegate = viewModel
    }
  }
}

// MARK: - Actionable prepended items pill.

extension DequeScrollView {
  private var deque: some View {
    ScrollViewReader { scrollProxy in
      ZStack(alignment: .top) {
        contentScrollView
        if let prependedItemsPillLabel = prependedItemsPillLabel, viewModel.prependedItemsPillIsShown {
          actionablePrependedItemsPill(label: prependedItemsPillLabel, scrollProxy: scrollProxy)
            .padding(.top, 12)
        }
      }
    }
  }

  private func actionablePrependedItemsPill(
    label: PrependedItemsPillLabel,
    scrollProxy: ScrollViewProxy
  ) -> some View {
    Button(
      action: {
        guard case let .value(items) = viewModel.itemsState, let firstItemId = items.first?.id else {
          return
        }
        withAnimation {
          scrollProxy.scrollTo(firstItemId)
        }
      },
      label: {
        label
      }
    )
    .transition(.move(edge: .top))
  }
}

#if DEBUG
  class DequeScrollViewPreviewsViewModel: DequeViewModel<Int> {
    @Published var timer: Timer?

    init() {
      super.init(hasPrependedItemsPill: true)
    }

    func startPrepending() {
      timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
        guard case let .value(items) = self.itemsState, let existingFirstItem = items.first else {
          return
        }
        self.setItemsState(.value([existingFirstItem - 1] + items))
      }
    }

    func stopPrepending() {
      timer?.invalidate()
      timer = nil
    }
  }

  class DequeScrollViewPreviewsItemsLoader: DequeAppendItemsLoader {
    private let viewModel: DequeScrollViewPreviewsViewModel

    init(viewModel: DequeScrollViewPreviewsViewModel) {
      self.viewModel = viewModel
    }

    func loadItemsToAppend(completion: @escaping (Bool) -> Void) -> AnyCancellable {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [viewModel] in
        let existingItems: [Int]
        if case let .value(items) = viewModel.itemsState {
          existingItems = items
        } else {
          existingItems = []
        }

        let existingLastItem = existingItems.last ?? 90
        viewModel.setItemsState(.value(existingItems + [existingLastItem + 1]))

        completion(true)
      }
      return AnyCancellable {}
    }
  }

  struct DequeScrollViewPreviewView: View {
    @ObservedObject var viewModel: DequeScrollViewPreviewsViewModel
    let appendItemsLoader: DequeScrollViewPreviewsItemsLoader

    var body: some View {
      VStack(alignment: .center, spacing: 0) {
        HStack(alignment: .center, spacing: 16) {
          Button("Start prepending") {
            viewModel.startPrepending()
          }
          Button("Stop prepending") {
            viewModel.stopPrepending()
          }
        }
        dequeScrollView
      }
    }

    private var dequeScrollView: some View {
      DequeScrollView(
        axis: .vertical,
        showsIndicators: true,
        itemSpacing: 4,
        viewModel: viewModel,
        prependedItemsPillLabel: {
          Text("Jump to latest")
        },
        content: { itemCoordinateNamespace in
          VStack(alignment: .center, spacing: 4) {
            if case let .value(items) = viewModel.itemsState {
              ForEach(items) { item in
                Text("\(item)")
                  .frame(height: 100)
                  .frame(maxWidth: .infinity)
                  .foregroundColor(Color.white)
                  .font(Font.system(size: 24).bold())
                  .background(
                    RoundedRectangle(cornerRadius: 12)
                      .fill(Color.red)
                  )
                  .padding(12)
                  .trackItemFrame(itemId: "\(item)", in: itemCoordinateNamespace)
              }
            }
          }
        }
      )
    }
  }

  struct DequeScrollViewPreviews: PreviewProvider {
    private static let viewModel = DequeScrollViewPreviewsViewModel()
    private static let appendItemsLoader = DequeScrollViewPreviewsItemsLoader(viewModel: viewModel)

    static var previews: some View {
      viewModel.appendItemsLoader = appendItemsLoader

      return DequeScrollViewPreviewView(viewModel: viewModel, appendItemsLoader: appendItemsLoader)
    }
  }
#endif
