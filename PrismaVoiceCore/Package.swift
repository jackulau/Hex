// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrismaVoiceCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PrismaVoiceCore", targets: ["PrismaVoiceCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Clipy/Sauce", branch: "master"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.11.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.9.1"),
    ],
    targets: [
	    .target(
	        name: "PrismaVoiceCore",
	        dependencies: [
	            "Sauce",
	            .product(name: "Dependencies", package: "swift-dependencies"),
	            .product(name: "DependenciesMacros", package: "swift-dependencies"),
	            .product(name: "Logging", package: "swift-log"),
	        ],
	        path: "Sources/PrismaVoiceCore",
	        linkerSettings: [
	            .linkedFramework("IOKit")
	        ]
	    ),
        .testTarget(
            name: "PrismaVoiceCoreTests",
            dependencies: ["PrismaVoiceCore"],
            path: "Tests/PrismaVoiceCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
