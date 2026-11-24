// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RivneRunningClubApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "RivneRunningClubApp",
            targets: ["RivneRunningClubApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "RivneRunningClubApp",
            path: "Sources/RivneRunningClubApp"
        ),
        .testTarget(
            name: "RivneRunningClubAppTests",
            dependencies: ["RivneRunningClubApp"],
            path: "Tests/RivneRunningClubAppTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
