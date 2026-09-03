import Foundation

/// 실행 인자로 화면을 세워 두는 길.
///
/// **시뮬레이터를 손으로 두드리지 않기 위해 있다.** 한글을 타이핑할 수 없고, 엉뚱한 것을
/// 눌러도 무엇을 눌렀는지 기록에 남지 않는다. 무엇을 띄울지 인자로 적으면 같은 화면을
/// 몇 번이든 똑같이 세울 수 있다 — `--query=` · `--tab=` · `--guide` 가 그렇게 늘었다.
///
/// **한 타입으로 모으는 것은 그 인자들이 스무 자리에 흩어져 있었기 때문이다.** 화면마다
/// `ProcessInfo.processInfo.arguments` 를 직접 뒤졌고, 이름을 잘라내는 방식도 자리마다
/// 조금씩 달랐다. 그래서 `--list-picking` 이 켜졌을 때 `--picking` 도 함께 켜지는지
/// 같은 것을 확인할 자리가 없었다.
public struct LaunchOptions: Sendable {

    private let arguments: [String]

    /// 이 실행이 받은 것.
    public static let current = LaunchOptions(ProcessInfo.processInfo.arguments)
    /// 아무것도 받지 않은 것. 미리보기와 시험이 쓴다.
    public static let none = LaunchOptions([])

    public init(_ arguments: [String]) {
        self.arguments = arguments
    }

    /// 값 없이 붙은 표시인가 — `--guide` · `--no-splash`.
    ///
    /// **정확히 그 이름이어야 한다.** 앞이 겹치는 것으로는 켜지지 않는다 —
    /// `--list-picking` 은 책장의 목록 고르기이고 `--picking` 은 묶음 화면의 고르기라,
    /// 둘이 한 화면에 겹쳐 설 수 있어 이름을 나눠 두었다.
    public func has(_ name: String) -> Bool {
        arguments.contains("--\(name)")
    }

    /// 이름 뒤에 붙은 값 — `--query=다이죠부`.
    ///
    /// 이름만 적고 값을 비운 것(`--folder=`)은 빈 문자열이지 없는 것이 아니다.
    /// 부르는 쪽이 그 둘을 갈라 쓴다 — 빈 값은 대개 "첫 번째 것"을 뜻한다.
    public func value(for name: String) -> String? {
        let prefix = "--\(name)="
        return arguments.first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    public func int(for name: String) -> Int? {
        value(for: name).flatMap(Int.init)
    }
}
