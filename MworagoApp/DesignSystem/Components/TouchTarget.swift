import SwiftUI

extension View {
    /// 그림은 작게 두고 **누르는 자리만 44pt 로 넓힌다.**
    ///
    /// 소리 · 갈피표 아이콘은 15~18pt 인데 누르는 자리를 따로 주지 않아, 손끝이 그림
    /// 크기만큼만 닿았다. Apple 이 권하는 바닥은 44pt 다. 그렇다고 그림을 키우면 카드의
    /// 글줄보다 단추가 앞에 나서므로, 둘레에 보이지 않는 여백을 붙여 누르는 자리만 키우고
    /// 그 여백을 도로 빼서 **놓이는 자리는 그대로** 둔다.
    ///
    /// `side` 는 그림이 차지하는 대략의 크기다. 여백은 `(44 - side) / 2` 씩 붙는다.
    func touchTarget(around side: CGFloat) -> some View {
        let inset = max(0, (44 - side) / 2)
        return padding(inset)
            .contentShape(Rectangle())
            .padding(-inset)
    }
}
