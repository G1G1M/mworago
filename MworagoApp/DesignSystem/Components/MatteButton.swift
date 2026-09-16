import SwiftUI

/// 검게 채운 단추와 회색 단추 — 시스템 표준 버튼을 쓰고 색만 앱의 먹으로 맞춘다.
///
/// **알약을 직접 칠하지 않는다.** 한때 면(`ink` · `grey4`)과 글자색을 손으로 칠한 알약을
/// 썼는데, 회색 쪽이 판 위에서 거의 보이지 않았고(면 236 · 판 252) 고치려고 테두리를
/// 둘렀다가 걷고 색을 진하게 하려다 멈추는 일이 이어졌다. 표준 버튼은 누를 때의 반응 ·
/// 막혔을 때의 흐림 · 손대기 좋은 크기 · 손쉬운 사용을 시스템이 맞춰 준다.
///
/// - 채운 것(`prominent`): `borderedProminent`. 하려는 일이다 — `저장` · `뒤집기` · `옮기기`.
/// - 채우지 않은 것: `bordered`. 먹을 옅게 깐 회색 면이다 — `그만두기` · `이전` · `다음`.
///
/// 글자체는 부르는 쪽의 `Text` 가 정한다. 시스템 글자체로 바뀌면 그 순간만 다른 앱이 된다.
struct MatteButton: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content
                .buttonStyle(.borderedProminent)
                // 어두울 때 먹(`ink`)은 흰색에 가깝다. 시스템이 올리는 흰 글자로는 안 읽힌다.
                .foregroundStyle(Theme.paper)
        } else {
            content
                .buttonStyle(.bordered)
                .foregroundStyle(Theme.ink)
        }
    }
}

extension View {
    /// 시스템 표준 버튼을 입힌다. 모양은 알약이 기본이고, 기호 하나만 담은 단추는 동그라미다.
    func matteButton(prominent: Bool = false,
                     shape: ButtonBorderShape = .capsule) -> some View {
        modifier(MatteButton(prominent: prominent))
            .buttonBorderShape(shape)
            .tint(Theme.ink)
    }
}
