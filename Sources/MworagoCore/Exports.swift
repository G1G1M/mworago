// 세 층을 한 이름으로 내보내는 우산.
//
// **부르는 쪽을 안 건드리기 위해 있다.** 앱과 도구들은 `import MworagoCore` 한 줄로
// 지금까지 쓰던 것을 그대로 쓴다 — 층을 나눈 것은 코어 안쪽의 사정이지, 코어를 쓰는
// 쪽이 매번 셋 중 어디에 있는지 알아야 할 일이 아니다.
//
// 층 사이의 방향은 여기가 아니라 `Package.swift` 가 강제한다.
//   Domain ← UseCases ← Infra
// 도메인은 위를 모르므로, 사전이 SQLite 든 메모리든 검색 코드는 달라지지 않는다.
//
// `@_exported` 는 공식 문법이 아니지만 오래도록 이 목적으로 쓰여 왔다.
// 이것이 없으면 부르는 쪽이 세 줄을 적어야 하고, 층 구성이 바뀔 때마다 그 줄이 흔들린다.
@_exported import MworagoDomain
@_exported import MworagoUseCases
@_exported import MworagoInfra
