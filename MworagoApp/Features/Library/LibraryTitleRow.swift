import SwiftUI

/// 책장의 이름과, 이 목록에서 손볼 수 있는 것.
///
/// 탭바에서 글자를 빼고 아이콘만 남겼으므로, **여기가 어디인지 말해 주는 것이
/// 화면 안에 있어야 한다.** 개수를 곁들이는 것은 세어 보라는 뜻이 아니라
/// 쌓이고 있다는 것이 보이라는 뜻이다.
struct LibraryTitleRow: View {
    /// 담긴 낱말 수.
    let wordCount: Int
    /// 낱말도 묶음도 없는가. 그때는 손볼 것이 없다.
    let isEmpty: Bool
    let grouping: LibraryView.Grouping
    /// 묶음을 지우는 손이 얹혔는가. `묶음별` 에서만 켠다.
    @Binding var editing: Bool
    /// `모두` 에서 낱말 고르기를 켠다. 고르는 상태는 책장이 쥔다.
    let onStartSelecting: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("책장")
                .font(Theme.korean(.heading, weight: .semibold))
                .foregroundStyle(Theme.ink)
            // 개수는 담긴 낱말을 센다. **`0` 은 적지 않는다** — 묶음만 만들어 둔
            // 책장에서 알려 주는 것이 없고, 빈 자리를 세어 보라는 말처럼 읽힌다.
            if wordCount > 0 {
                Text("\(wordCount)")
                    .font(Theme.korean(.body))
                    .foregroundStyle(Theme.grey2)
            }

            Spacer(minLength: 12)

            // **보기마다 손볼 것이 다르다.** 묶음별에서 지우는 것은 묶음이고,
            // 모두에서 손보는 것은 낱말이다. 날짜는 사람이 만든 자리가 아니라
            // 담은 때가 만든 자리라 지울 것도 고를 것도 없다 —
            // 예전에는 거기서도 단추가 떠 있었지만 눌러도 아무 일이 없었다.
            if !isEmpty {
                switch grouping {
                case .folders:
                    Button {
                        withAnimation(.select) { editing.toggle() }
                    } label: {
                        Text(editing ? "완료" : "지우기")
                            .font(Theme.korean(.body, weight: editing ? .medium : .regular))
                            .foregroundStyle(editing ? Theme.ink : Theme.grey2)
                    }
                    .buttonStyle(.plain)
                case .list:
                    Button(action: onStartSelecting) {
                        Text("고르기")
                            .font(Theme.korean(.body))
                            .foregroundStyle(Theme.grey2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("낱말을 골라 옮기거나 지웁니다")
                case .days:
                    EmptyView()
                }
            }
        }
    }
}
