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

public protocol ExtendedBundleFinder: AnyObject {
  static func find(in package: String, target: String, fallback: Bundle) -> Bundle
}

extension ExtendedBundleFinder {
  public static func find(file: String = #fileID, fallback: Bundle = .main) -> Bundle {
    find(in: file.components(separatedBy: "/").first ?? file, fallback: fallback)
  }

  public static func find(in package: String, fallback: Bundle = .main) -> Bundle {
    find(in: package, target: package, fallback: fallback)
  }

  public static func find(in package: String, target: String, fallback: Bundle = .main) -> Bundle {
    let name = package + "_" + target
    let packageBundle = Bundle(for: Self.self)

    var candidates = [
      // Bundle should be present here when the package is linked into an App.
      Bundle.main.resourceURL,

      // Bundle should be present here when the package is linked into a framework.
      packageBundle.resourceURL,

      // For command-line tools.
      Bundle.main.bundleURL,
    ]

    #if DEBUG
      candidates += [
        // Bundle should be present here when running previews from a different package
        // (this is the path to "…/Debug-iphonesimulator/").
        packageBundle.resourceURL?.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent(),
        packageBundle.resourceURL?.deletingLastPathComponent().deletingLastPathComponent(),
      ]
    #endif

    for candidate in candidates {
      let bundlePath = candidate?.appendingPathComponent(name).appendingPathExtension("bundle")
      if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
        return bundle
      }
    }

    #if DEBUG
      fatalError("unable to find bundle named \(name) for class \(Self.self)")
    #else
      return fallback
    #endif
  }
}
