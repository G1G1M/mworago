import SwiftUI

extension View {
    /// 글이 서는 기둥 — 폭을 묶고 화면 가운데 세운다. 글줄은 왼쪽에서 시작한다.
    ///
    /// 폭만 묶어 두면 넓은 화면(아이패드)에서 덩어리가 왼쪽에 붙어 오른쪽이 통째로 빈다.
    /// 그래서 늘 두 줄이 짝으로 붙는데, 여덟 화면이 그 두 줄을 각자 적고 있었다.
    func column(_ width: CGFloat = Theme.readWidth) -> some View {
        frame(maxWidth: width, alignment: .leading)
            .frame(maxWidth: .infinity)
    }

    /// 읽는 화면의 몸 — 좌우 여백 · 아래 여백 · 기둥.
    ///
    /// 위 여백만 화면마다 다르다(이름이 큰 화면은 내비 바가 위를 맡는다). 그것만 받는다.
    /// 여백을 기둥 **안쪽**에 두는 차례도 여기서 지킨다 — 폭을 잰 뒤에 붙이면 덩어리가
    /// `readWidth + 여백` 이 되어 재 둔 폭이 실제와 어긋난다.
    func readingPage(top: CGFloat = 0) -> some View {
        padding(.horizontal, Theme.gutter)
            .padding(.top, top)
            .padding(.bottom, Theme.screenBottom)
            .column()
    }
}
