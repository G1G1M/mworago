import SwiftUI

/// 고르는 중인 줄 앞에 서는 동그라미.
///
/// 책장의 `모두` 목록과 묶음 화면이 **같은 고르기**를 쓴다. 한쪽 동그라미만 크기나
/// 여백이 달라지면, 같은 일을 하는 두 화면이 다른 문법으로 보인다.
struct SelectionMark: View {
    let isPicked: Bool

    var body: some View {
        Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 21))
            .foregroundStyle(isPicked ? Theme.ink : Theme.grey3)
            .padding(.leading, Theme.gutter)
            .accessibilityHidden(true)   // 줄 전체가 이미 고르는 단추다
    }
}
