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

public let defaultAnimationDuration = 0.35

struct OnAnimating<AnimatedData>: Animatable, ViewModifier where AnimatedData: VectorArithmetic {
  let targetValue: AnimatedData
  let progress: ((AnimatedData) -> Void)?
  let completion: (() -> Void)?

  var animatableData: AnimatedData {
    didSet {
      let newValue = animatableData
      if newValue == targetValue {
        DispatchQueue.main.async { [completion] in
          completion?()
        }
      } else {
        DispatchQueue.main.async { [progress] in
          progress?(newValue)
        }
      }
    }
  }

  func body(content: Content) -> some View {
    content
  }
}

extension View {
  public func onAnimating<AnimatedData: VectorArithmetic>(
    of value: AnimatedData,
    progress: ((AnimatedData) -> Void)? = nil,
    completion: (() -> Void)? = nil
  ) -> some View {
    modifier(OnAnimating(
      targetValue: value,
      progress: progress,
      completion: completion,
      animatableData: value
    ))
  }
}
