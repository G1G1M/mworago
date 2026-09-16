import SwiftUI
import MworagoCore

/// 가나와, 그 낱말이 무엇인지 말해 주는 한자.
///
/// **앱은 오래도록 한자를 한 자도 그리지 않았다.** 소리로 찾아 들어오는 앱이라
/// 가나를 얼굴로 세웠는데, 그러다 보니 `やめる` 를 찾으면 화면에 `やめる` 만 셋이
/// 늘어섰다 — 止める(그만두다) · 辞める(사직하다) · 病める(병들다) 가 갈리지 않았다.
/// 뜻은 이미 표제항마다 따로 붙어 있었으니 빠진 것은 정확도가 아니라
/// **어느 것인지 보이는 것**이었다.
///
/// **가나가 먼저고 한자는 괄호 안이다.** 반대로 두면(한자 본문 + 가나 위) 파파고나
/// 구글이 되는데, 그쪽은 한자를 읽을 줄 아는 사람이 원문을 붙여 넣는 앱이다.
/// 이 앱에 오는 사람은 한자를 칠 수 없어서 소리로 온 사람이라, 자기가 친 소리와
/// 가장 가까운 것이 맨 앞에 서야 한다.
///
/// 괄호는 **있을 때만** 그린다 — 가나로만 쓰는 낱말에 `ありがとう(ありがとう)` 를
/// 그리면 같은 말을 두 번 적는 꼴이다. 무엇이 한자를 가졌는지는
/// `SearchResult.kanji` · `CollectedWord.kanji` 가 정한다.
struct Headword: View {
    let reading: String
    let kanji: String?
    var size: Theme.Size = .hero
    var weight: Font.Weight = .medium
    /// 가나의 색. 한자는 늘 한 단 흐리다 — 딸린 것이지 답이 아니다.
    var tint: Color = Theme.ink

    var body: some View {
        // **한 줄에 안 들어가면 괄호가 아래로 내려간다.**
        //
        // 긴 관용구에서 `いってきます (行って来ます)` 가 한 줄을 넘긴다. 그대로 두면
        // SwiftUI 가 가장 잘 접히는 것을 접는데, 그게 하필 **가나 쪽**이라 낱말이
        // 두 줄로 끊기고 괄호는 멀쩡히 붙어 있는 꼴이 됐다. 접혀야 하는 것은
        // 딸린 쪽이다.
        //
        // 폭을 재서 기기로 가르지 않고 `ViewThatFits` 에 맡긴다 — 고르기 머리줄이
        // 쓰는 것과 같은 문법이다(`SelectionHead`). 들어가면 한 줄, 안 들어가면
        // 두 줄이고, 글자 크기를 키운 사람도 알아서 두 줄로 내려간다.
        //
        // **한 줄짜리는 `fixedSize` 여야 한다.** 그러지 않으면 줄여서라도 들어가므로
        // `ViewThatFits` 가 늘 첫 번째를 고른다.
        Group {
            if kanji == nil {
                kana
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        kana
                        parenthesis
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    // 두 줄일 때 괄호는 **가나 아래 왼쪽**에서 시작한다. 이 앱의 글이
                    // 다 그 자리에서 시작하므로 여기만 들여쓰면 줄이 어긋나 보인다.
                    // 사이는 3 — 두 줄이지만 한 낱말이라 층으로 갈려 보이면 안 된다.
                    VStack(alignment: .leading, spacing: 3) {
                        kana
                        parenthesis
                    }
                }
            }
        }
        // 읽는 기계에는 괄호를 읽히지 않는다 — 소리로 찾아온 사람에게 필요한 것은
        // 가나이고, 한자는 눈으로 가리키는 표시다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading)
    }

    private var kana: some View {
        Text(reading)
            .font(Theme.japanese(size, weight: weight))
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var parenthesis: some View {
        if let kanji {
            Text("(\(kanji))")
                .font(Theme.japanese(size.beside))
                .foregroundStyle(Theme.grey2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
