import SwiftUI
import MworagoCore

/// 품사 꼬리표 — `동사` · `명사` · `관용구`.
///
/// **실제 사전이 하는 것과 같다.** 낱말마다 늘 있으므로 자리가 고정되고, 사전에서
/// 먼저 알고 싶은 것("이 낱말이 동사인가 명사인가")에 답한다.
///
/// 찾기 카드에만 있다가 책장·묶음·상세·연습으로 넓혔다. 같은 낱말인데 화면마다
/// 알려 주는 것이 다르면, 사용자는 어느 화면이 진짜인지 매번 판단해야 한다.
struct PartOfSpeechTag: View {
    let name: String

    var body: some View {
        Text(name)
            .font(Theme.korean(.tag))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.grey4, in: Capsule())
            .foregroundStyle(Theme.grey1)
    }
}

extension WordClass {
    /// 화면에 적을 이름.
    ///
    /// 코어의 `koreanName` 은 모델에게 줄 프롬프트용이라 기능어·관용구를 `nil` 로 둔다.
    /// 화면에서 그대로 비우면 카드마다 꼬리표가 있다 없다 하므로, 사전이 하듯 이름을
    /// 붙여 준다. 갈래를 정말 모르는 것(`other`)만 비운다 — 지어내지 않는다.
    var displayName: String? {
        switch self {
        case .verb: "동사"
        case .adjective: "형용사"
        case .noun: "명사"
        case .adverb: "부사"
        case .expression: "관용구"
        case .affix: "접사"
        case .function: "조사·어미"
        case .other: nil
        }
    }
}
