import MworagoCore

/// 온보딩을 봤는지.
///
/// **적어 두는 일은 밖에서 한다**(`PreferenceStoring`). 예전에는 이 enum 이 직접
/// Application Support 를 찾아 빈 파일을 만들었다 — 뷰 파일 안에 파일 IO 가
/// 박혀 있었고, 같은 여섯 줄이 모습 설정과 모은 낱말 자리에도 복붙되어 있었다.
///
/// **값이 아니라 표시다.** 오래도록 빈 파일이었으므로 그 파일이 있으면 본 것으로
/// 친다 — 값으로 읽으면 이미 본 사람에게 온보딩이 다시 뜬다.
enum OnboardingSeen {
    /// 적어 둘 때 쓰는 이름. 예전에 남긴 빈 파일과 같은 이름이라 그대로 이어진다.
    static let key = "onboarding-seen"

    /// `--onboarding` 으로 언제든 다시 띄운다. 봤는지와 무관하게 화면을 확인하려는 것이다.
    static var forced: Bool { LaunchOptions.current.has("onboarding") }

    /// `--onboarded` 로 건너뛴다 — **다른 화면을 찍으려는데 앞을 막고 서 있을 때**다.
    ///
    /// 새 시뮬레이터는 아무것도 안 봤으므로 무엇을 띄우든 온보딩이 먼저 뜬다.
    /// `--query=` 도 `--tab=` 도 그 뒤에서 조용히 흘러가 버려서, 등록용 스크린샷을
    /// 찍으려면 다섯 장을 손으로 넘겨야 했다. `--no-splash` 와 같은 취지다.
    ///
    /// **적어 두지는 않는다.** 이 인자로 건너뛴 것은 본 것이 아니므로, 인자 없이
    /// 다시 열면 온보딩이 그대로 나온다.
    static var skipped: Bool { LaunchOptions.current.has("onboarded") }
}
