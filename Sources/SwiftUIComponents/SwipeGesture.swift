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

public enum SwipeDirection: Equatable {
  case up
  case down
  case left
  case right
}

extension View {
  public func onSwipe(minimumDistance: CGFloat = 10, handler: @escaping ([SwipeDirection]) -> Void) -> some View {
    simultaneousGesture(
      DragGesture(minimumDistance: minimumDistance, coordinateSpace: .local)
        .onEnded { value in
          var directions = [SwipeDirection]()
          if value.translation.width < 0 {
            directions.append(.left)
          }
          if value.translation.width > 0 {
            directions.append(.right)
          }
          if value.translation.height < 0 {
            directions.append(.up)
          }
          if value.translation.height > 0 {
            directions.append(.down)
          }

          if !directions.isEmpty {
            handler(directions)
          }
        }
    )
  }
}
