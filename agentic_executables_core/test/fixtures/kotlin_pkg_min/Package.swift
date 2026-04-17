// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "Foo",
  products: [
    .library(name: "Foo", targets: ["Foo"]),
  ],
  dependencies: [],
  targets: [
    .target(name: "Foo", dependencies: []),
  ]
)
