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
  dependencies: [],
  targets: [
    .target(
      name: "SwiftUIComponents",
      dependencies: []
    ),
  ]
)
