// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Mworago",
    platforms: [.macOS(.v15)],
    targets: [
        // 앱으로 그대로 옮겨갈 순수 로직. Foundation 외 의존성 없음.
        .target(name: "MworagoCore"),

        // M0 측정 도구. 케이스를 돌려 정확도 표를 찍는다.
        .executableTarget(name: "SpikeRunner", dependencies: ["MworagoCore"]),

        .testTarget(name: "MworagoCoreTests", dependencies: ["MworagoCore"]),
    ]
)
