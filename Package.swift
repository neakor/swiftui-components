// swift-tools-version: 5.6

import PackageDescription

let package = Package(
  name: "SwiftUIComponents",
  platforms: [
    .iOS(.v15),
  ],
  products: [
    .library(
      name: "SwiftUIComponents",
      targets: ["SwiftUIComponents"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", branch: "master"),
  ],
  targets: [
    .target(
      name: "SwiftUIComponents",
      dependencies: [
        .product(name: "Introspect", package: "SwiftUI-Introspect"),
      ]
    ),
  ]
)
