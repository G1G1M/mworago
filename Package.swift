// swift-tools-version: 6.2
import PackageDescription

// 폴더 구조는 SpringLab 을 따른다.
//   Mworago/       역할별로 나눈 앱 소스 (Model · Store · Runner)
//   MworagoTests/  테스트. 평면으로 두고 파일 이름으로 구분한다
//   Tools/         앱에 실리지 않는 것들 — 측정기, 사전 내려받기, 원본 데이터
//   docs/          기록
let package = Package(
    name: "Mworago",
    platforms: [.macOS(.v15)],
    targets: [
        // 앱으로 그대로 옮겨갈 순수 로직. Foundation 외 의존성 없음.
        .target(name: "MworagoCore", path: "Mworago",
                // 사전 색인은 SQLite 파일이다. iOS·macOS 에 시스템으로 들어 있어 의존성이 늘지 않는다.
                linkerSettings: [.linkedLibrary("sqlite3")]),

        // M0 측정 도구. 케이스를 돌려 정확도 표를 찍는다.
        .executableTarget(name: "SpikeRunner", dependencies: ["MworagoCore"], path: "Tools/SpikeRunner"),

        .testTarget(name: "MworagoTests", dependencies: ["MworagoCore"], path: "MworagoTests"),
    ]
)
