import SwiftUI
import MworagoCore

/// 낱말의 얼굴 — 가나.
///
/// **한자를 달지 않는다.** 한때 가나 옆 괄호에 한자를 달았다(`やめる (止める)`).
/// 같은 소리의 다른 낱말(止める · 辞める · 病める)을 가르려던 것이었는데, 이 앱에 오는
/// 사람은 한자를 읽으려는 것이 아니라 들은 소리가 무슨 말인지 알려는 것이다.
/// 가르는 일은 뜻이 한다 — 다른 뜻이 있으면 카드가 `1.` `2.` 로 번호를 달아 늘어놓는다.
/// 한자음 줄도 같은 까닭으로 넣었다가 뺐다(낱말마다 소리가 달라 틀리게 보였다).
struct Headword: View {
    let reading: String
    var size: Theme.Size = .hero
    var weight: Font.Weight = .medium
    var tint: Color = Theme.ink

    var body: some View {
        Text(reading)
            .font(Theme.japanese(size, weight: weight))
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}
