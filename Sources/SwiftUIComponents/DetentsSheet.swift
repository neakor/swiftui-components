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

extension View {
  public func detentsSheet<Content: View>(
    isPresented: Binding<Bool>,
    detents: [UISheetPresentationController.Detent] = [.medium(), .large()],
    grabberVisible: Bool = true,
    cornerRadius: CGFloat = 32,
    content: @escaping () -> Content
  ) -> some View {
    detentsSheet(
      // Translate the boolean binding into an optional item binding for the sheet host. When the boolean binding is
      // explicitly updated by the owner, the sheet host is triggered to update by SwiftUI. The sheet host then
      // queries this mapped binding and receive the appropriate value that causes the sheet to present or dismiss.
      item: Binding<Bool?>(
        get: {
          isPresented.wrappedValue ? true : nil
        },
        set: { value in
          isPresented.wrappedValue = value == true ? true : false
        }
      ),
      detents: detents,
      grabberVisible: grabberVisible,
      cornerRadius: cornerRadius,
      content: { _ in
        content()
      }
    )
  }

  public func detentsSheet<Content: View, Item: Identifiable>(
    item: Binding<Item?>,
    detents: [UISheetPresentationController.Detent] = [.medium(), .large()],
    grabberVisible: Bool = true,
    cornerRadius: CGFloat = 32,
    content: @escaping (Item) -> Content
  ) -> some View {
    // Install the sheet host view controller into the SwiftUI view hierarchy so it can present the sheet.
    background(
      SheetHost(
        item: item,
        detents: detents,
        grabberVisible: grabberVisible,
        cornerRadius: cornerRadius,
        content: content
      )
    )
  }
}

extension Bool: Identifiable {
  public var id: String {
    "\(self)"
  }
}

// MARK: - Host for the sheet view controller

struct SheetHost<Content: View, Item: Identifiable>: UIViewControllerRepresentable {
  let item: Binding<Item?>
  let detents: [UISheetPresentationController.Detent]
  let grabberVisible: Bool
  let cornerRadius: CGFloat
  let content: (Item) -> Content

  // Keep track of the current presented item to determine if the current sheet should be replaced when the item
  // changes.
  @State private var currentPresentedItem: Item?

  func makeUIViewController(context: Context) -> UIViewController {
    // The sheet host is an empty view controller installed in the SwiftUI view hierarchy. It serves as the presenting
    // view controller for the actual sheet view controller that contains the SwiftUI sheet content.
    UIViewController()
  }

  func makeCoordinator() -> SheetDelegate {
    // Reset the tracked item values when the sheet delegate reports dismissal. This are dismissals triggered by the
    // user tapping outside the sheet or dragging the sheet down.
    SheetDelegate(didDismiss: resetItemValues)
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    if let item = item.wrappedValue {
      if let currentPresentedItem = currentPresentedItem {
        // If the current presented item is not the same as the new item, dismiss the current one before presenting
        // the new one.
        if item.id != currentPresentedItem.id {
          dismiss(from: uiViewController, completion: {
            present(from: uiViewController, delegate: context.coordinator, item: item)
          })
        }
      } else {
        // Presenting a brand new item.
        present(from: uiViewController, delegate: context.coordinator, item: item)
      }
    } else {
      // Reset the tracked items when a dismissal is triggered by the binding value becoming `nil`. This is caused
      // by the owner of the binding explicitly setting the item to `nil` to dismiss the sheet.
      dismiss(from: uiViewController, completion: resetItemValues)
    }
  }

  private func present(
    from hostViewController: UIViewController,
    delegate: SheetDelegate,
    item: Item
  ) {
    DispatchQueue.main.async {
      // Since this modifies the state property, it needs to be performed asynchronously per SwiftUI. This property
      // needs to be updated before the sheet is actually presented to ensure SwiftUI triggering multiple invocations
      // to `updateUIViewController` does not cause duplicate presentations.
      currentPresentedItem = item

      hostViewController.present(
        SheetViewController(
          detents: detents,
          grabberVisible: grabberVisible,
          cornerRadius: cornerRadius,
          delegate: delegate,
          item: item,
          content: content
        ),
        animated: true
      )
    }
  }

  private func dismiss(from hostViewController: UIViewController, completion: (() -> Void)? = nil) {
    hostViewController.dismiss(animated: true, completion: completion)
  }

  private func resetItemValues() {
    // Since this modifies the state property, it needs to be performed asynchronously per SwiftUI.
    DispatchQueue.main.async {
      item.wrappedValue = nil
      currentPresentedItem = nil
    }
  }
}

// The delegate used to notify the host sheet that it has been dismissed. Cannot rely on the programmatic `dismiss`
// function's completion closure since the user can tap outside the sheet or drag the sheet to interactively dismiss.
class SheetDelegate: NSObject, UISheetPresentationControllerDelegate {
  private let didDismiss: () -> Void

  init(didDismiss: @escaping () -> Void) {
    self.didDismiss = didDismiss
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    didDismiss()
  }
}

// MARK: - View controller for SwiftUI sheet content

class SheetViewController<Content: View, Item: Identifiable>: UIHostingController<Content> {
  init(
    detents: [UISheetPresentationController.Detent],
    grabberVisible: Bool,
    cornerRadius: CGFloat,
    delegate: UISheetPresentationControllerDelegate,
    item: Item,
    content: (Item) -> Content
  ) {
    super.init(rootView: content(item))

    if let sheetPresentationController = sheetPresentationController {
      sheetPresentationController.detents = detents
      sheetPresentationController.largestUndimmedDetentIdentifier = nil
      sheetPresentationController.prefersScrollingExpandsWhenScrolledToEdge = true
      sheetPresentationController.prefersEdgeAttachedInCompactHeight = true
      sheetPresentationController.widthFollowsPreferredContentSizeWhenEdgeAttached = true
      sheetPresentationController.prefersGrabberVisible = grabberVisible
      sheetPresentationController.preferredCornerRadius = cornerRadius
      sheetPresentationController.delegate = delegate
    }
  }

  @MainActor
  required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

#if DEBUG
struct DetentsSheetItemPreview: View {
  @State private var item: Int?

  var body: some View {
    Button("Present item sheet", action: incrementItem)
    .detentsSheet(item: $item) { value in
      VStack(alignment: .center, spacing: 16) {
        Button("Hello World \(value)!", action: incrementItem)
        Button("Dismiss") {
          item = nil
        }
      }
    }
  }

  private func incrementItem() {
    if let item = item {
      self.item = item + 1
    } else {
      item = 0
    }
  }
}

extension Int: Identifiable {
  public var id: String {
    "\(self)"
  }
}

struct DetentsSheetBoolPreview: View {
  @State private var isPresented = false

  var body: some View {
    Button("Present bool sheet") {
      isPresented = true
    }
    .detentsSheet(isPresented: $isPresented) {
      Button("Dismiss") {
        isPresented = false
      }
    }
  }
}

struct DetentsSheetPreviewProvider: PreviewProvider {
  static var previews: some View {
    DetentsSheetItemPreview()
    DetentsSheetBoolPreview()
  }
}
#endif
