import SwiftUI
import MworagoCore

/// 글자 하나 — 시트에 실어 보내려면 무엇으로 식별되는지가 있어야 한다. 글자가 곧 그것이다.
///
/// 표에서도 쓰고(어느 칸을 눌렀는가) 상세에서도 쓴다(지금 어느 장을 보고 있는가).
struct Glyph: Identifiable {
    let kana: String
    var id: String { kana }

    /// 표를 읽는 차례 그대로 늘어선 글자 전부. 넘겨 보는 차례가 이것이다.
    static let all: [Glyph] = KanaTable.ordered.map(Glyph.init)
}
