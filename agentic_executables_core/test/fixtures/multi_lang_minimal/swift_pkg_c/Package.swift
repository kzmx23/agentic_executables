// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "SwiftPkgC",
  products: [
    .library(name: "SwiftPkgC", targets: ["SwiftPkgC"]),
  ],
  targets: [
    .target(name: "SwiftPkgC"),
  ]
)
