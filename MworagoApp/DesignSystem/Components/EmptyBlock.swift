import SwiftUI

extension View {
    /// 빈 화면의 글 덩어리를 세우는 자리 — 책장과 연습이 같이 쓴다.
    ///
    /// 두 화면이 **같은 문법으로 선다** — 폭 안쪽 여백 · `readWidth` · 공유 높이 ·
    /// 남은 자리 채우기. 결과만 비슷하게 맞춰 두면 한쪽을 손볼 때 다시 어긋난다.
    ///
    /// 좌우 여백을 폭 **안쪽**에 둔다. 폭을 잰 뒤에 붙이면 덩어리가
    /// `readWidth + 여백` 이 되어 재 둔 폭이 실제와 어긋난다.
    ///
    /// 글은 왼쪽에서 시작하되 **덩어리는 화면 가운데 선다.** 아이패드처럼 넓은 화면에서
    /// 폭만 묶어 두면 덩어리가 왼쪽에 붙어, 오른쪽이 통째로 비어 보인다.
    /// 첫 줄은 두 화면에서 같은 높이에 선다 — 자세한 까닭은 `Theme.emptyBlockHeight`.
    func emptyBlockFrame() -> some View {
        padding(.horizontal, Theme.gutter)
            .frame(maxWidth: Theme.readWidth, alignment: .leading)
            .frame(minHeight: Theme.emptyBlockHeight, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
