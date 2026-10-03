import SwiftUI

extension Text {
    /// 「갈피표」라는 말 뒤에 찾기 카드의 그 그림을 괄호로 붙인다 — `갈피표(🔖)`.
    ///
    /// 갈피표는 이 앱이 붙인 이름이고, 찾기 카드에는 글자 없이 그림만 있다. 처음 온 사람은
    /// "갈피표를 누르면"을 읽고도 어느 단추인지 짚을 수 없었다. 그림은 **속이 빈 쪽**이다 —
    /// 누르기 전에 카드에서 보는 모양이 그것이다.
    ///
    /// 글 안에 끼워 넣으므로 글자 크기를 키우면 그림도 같이 커지고 줄도 글을 따라 바뀐다.
    /// 읽어 주기에는 그림을 빼고 원래 문장을 준다. 그대로 두면 "갈피표 괄호 북마크 괄호"로 읽힌다.
    static func bookmarkGuide(_ line: String) -> Text {
        guard let word = line.range(of: "갈피표") else { return Text(line) }
        let before = Text(line[..<word.upperBound])
        let after = Text(line[word.upperBound...])
        return Text("\(before)(\(Image(systemName: "bookmark")))\(after)")
            .accessibilityLabel(line)
    }
}
