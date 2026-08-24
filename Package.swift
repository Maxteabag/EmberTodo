// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmberTodo",
    platforms: [.iOS(.v17)],
    products: [.library(name: "EmberTodo", targets: ["EmberTodo"])],
    targets: [
        .target(name: "TodoCore", path: "Sources/TodoCore"),
        .target(
            name: "EmberTodo",
            dependencies: ["TodoCore"],
            path: "Sources/EmberTodo",
            exclude: ["Resources/Info.plist"],
            resources: [.process("Resources/Assets.xcassets")]
        ),
        .testTarget(name: "TodoCoreTests", dependencies: ["TodoCore"], path: "Tests/TodoCoreTests")
    ]
)
