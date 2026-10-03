import SwiftUI
import MworagoCore

/// 찾기의 갈피표 — 낱말 카드와 문장 머리줄이 같이 쓴다.
///
/// **자동으로 모으지 않는다.** 찾아본 것을 다 쌓으면 오타와 헛짚은 것까지 교재가 된다.
/// 무엇이 내게 걸린 말이었는지는 사용자만 안다.
///
/// 담긴 것은 채워진 갈피표다. 강조를 색으로 나누지 않으므로 채움과 비움으로만 가른다.
///
/// **담을 때는 어디에 넣을지 묻고, 뺄 때는 묻지 않는다.** 무르는 일에까지 확인을
/// 붙이면 잘못 누른 것을 되돌리는 데 두 번이 든다. 그래서 담기는 위로 알리고(`onCollect`,
/// 판은 화면에 하나여야 한다) 빼기는 여기서 바로 한다.
struct BookmarkButton: View {
    let word: CollectedWord
    /// 읽어 주기에서 부를 이름 — `あたま 담기` · `문장 담기`.
    let name: String
    var onCollect: (CollectedWord) -> Void

    /// **넘겨받지 않고 환경에서 꺼낸다.** 예전에는 옵셔널로 받아 없으면 갈피표를
    /// 그리지 않았는데, 그 nil 분기가 카드를 거쳐 찾기 화면까지 붙어 있었다.
    /// 환경에 없으면 그 자리에서 멎으므로, 조립 루트가 빠뜨린 것을 바로 알게 된다.
    @Environment(CollectionStore.self) private var collection

    var body: some View {
        let held = collection.contains(word)
        Button {
            if held { collection.remove(word) } else { onCollect(word) }
        } label: {
            Image(systemName: held ? "bookmark.fill" : "bookmark")
                .font(Theme.icon(.control))
                .foregroundStyle(held ? Theme.ink : Theme.grey3)
        }
        .buttonStyle(.plain)
        // **손끝에도 알린다.** 갈피표는 그림만 채워지고 마는데, 누른 자리와 바뀌는
        // 자리가 같아서 눈으로는 "됐나?" 가 남는다. 담을 때와 뺄 때의 결을 나눈다 —
        // 담기는 무언가 얹히는 일이고 빼기는 도로 무르는 일이다.
        .sensoryFeedback(held ? .increase : .decrease, trigger: held)
        .accessibilityLabel(held ? "\(name) 빼기" : "\(name) 담기")
    }
}

extension CollectedWord {
    /// 찾은 답 하나를 담을 낱말로 만든다.
    ///
    /// 세 자리(카드의 갈피표 · 실행 인자 `--collect` · `--collecting`)가 각자 짓고 있었고,
    /// 그중 하나는 품사를 빠뜨려 담긴 낱말에 꼬리표가 없었다.
    init(result: SearchResult, hangul: String, gloss: String) {
        self.init(headword: result.headword,
                  reading: result.reading,
                  hangul: hangul,
                  gloss: gloss,
                  partOfSpeech: result.entry.wordClass.displayName)
    }
}
