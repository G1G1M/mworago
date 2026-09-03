// swift-tools-version: 6.2
import PackageDescription

// 폴더 구조는 클린 아키텍처의 층을 그대로 따른다.
//   Sources/MworagoDomain/    엔티티와 포트. Foundation 밖을 모른다 (Kana · Words · Ports)
//   Sources/MworagoUseCases/  찾고 나누고 줄 세우는 일. 도메인만 안다 (Search · Sentence)
//   Sources/MworagoInfra/     SQLite · 파일 · 모델 — 바깥과 닿는 것들
//                             (Dictionary · Storage · Translation)
//   Sources/MworagoCore/      셋을 한 이름으로 내보내는 우산
//   MworagoTests/             테스트. 시험하는 층으로 나눈다 (Domain · UseCases · Infra)
//   Tools/                    앱에 실리지 않는 것들 — 측정기(SpikeRunner · Translator),
//                             내려받기(fetch), 굽기(bake), 화면 재기(inspect), 원본(data)
//   docs/                     기록
//
// **층 안을 다시 폴더로 나누는 것은 읽는 사람을 위한 것이다.** 타깃 하나에 파일 여덟이
// 평면으로 놓이면 무엇이 무엇의 짝인지 이름으로만 짐작해야 한다. 폴더 경계는 컴파일러가
// 지켜 주지 않으므로(같은 타깃 안이라 서로 다 보인다) 규칙이 아니라 안내다 —
// 지켜야 하는 경계는 아래 타깃 사이의 `dependencies` 가 지킨다.
//
// **의존 방향을 컴파일러가 지킨다.** 층을 폴더로만 나누면 규칙이 문서에 남고,
// 그 문서는 언젠가 어긋난다. 타깃으로 나누면 도메인에서 SQLite 를 부르는 순간
// 빌드가 멎는다.
let package = Package(
    name: "Mworago",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "MworagoCore", targets: ["MworagoCore"]),
    ],
    targets: [
        // 엔티티와 포트. 가나 표·활용형·낱말·사전 표제항, 그리고 바깥에 무엇을
        // 요구하는지(사전 조회·자원 자리·설정 저장·소리)를 적은 프로토콜들.
        .target(name: "MworagoDomain", path: "Sources/MworagoDomain"),

        // 찾고 나누고 줄 세우는 일. 사전이 파일인지 메모리인지 모른 채 돈다.
        .target(name: "MworagoUseCases", dependencies: ["MworagoDomain"],
                path: "Sources/MworagoUseCases"),

        // 바깥과 닿는 것들. 사전 색인은 SQLite 파일이다 —
        // iOS·macOS 에 시스템으로 들어 있어 의존성이 늘지 않는다.
        .target(name: "MworagoInfra", dependencies: ["MworagoDomain", "MworagoUseCases"],
                path: "Sources/MworagoInfra",
                linkerSettings: [.linkedLibrary("sqlite3")]),

        // 우산. 앱과 도구는 이것 하나만 부른다.
        .target(name: "MworagoCore",
                dependencies: ["MworagoDomain", "MworagoUseCases", "MworagoInfra"],
                path: "Sources/MworagoCore"),

        // M0 측정 도구. 케이스를 돌려 정확도 표를 찍는다.
        .executableTarget(name: "SpikeRunner", dependencies: ["MworagoCore"], path: "Tools/SpikeRunner"),

        // 한국어 뜻을 미리 굽는다. 온디바이스 모델을 쓰므로 macOS 26 이상에서만 동작한다.
        .executableTarget(name: "Translator", dependencies: ["MworagoCore"], path: "Tools/Translator"),

        // 시험은 층을 넘어 안쪽까지 본다. 우산으로는 `@testable` 이 통하지 않으므로
        // 파일마다 필요한 층을 직접 부른다.
        .testTarget(name: "MworagoTests",
                    dependencies: ["MworagoDomain", "MworagoUseCases", "MworagoInfra"],
                    path: "MworagoTests"),
    ]
)
