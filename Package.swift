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
    .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", .upToNextMajor(from: "0.1.4")),
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
