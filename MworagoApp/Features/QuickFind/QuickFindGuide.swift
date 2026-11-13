import SwiftUI
import AppIntents

/// 앱을 열지 않고 찾는 길을 알려 주는 화면.
///
/// 1.1 부터 동작 버튼 · 단축어로 찾는 길(`QuickFindIntent`)이 있었는데, 앱 안 어디에도
/// 그 말이 없어 아무도 몰랐다. 시스템은 단축어 목록에 앱 이름으로 올려 줄 뿐 쓰라고
/// 알려 주지는 않는다.
///
/// **설정 › 동작 버튼 화면으로 바로 보내는 공개된 문이 없다.** 그래서 거는 순서는 글로
/// 적고, 갈 수 있는 곳(단축어 앱의 이 앱 자리)만 단추로 잇는다.
///
/// 두 자리에서 연다 — 설정의 줄(밀어 들어감)과 찾기 화면의 쪽지(시트).
struct QuickFindGuide: View {

    /// 거는 순서. **화면에서 실제로 누르는 이름을 그대로 적는다** — 「」 안의 말은
    /// 설정 앱과 이 앱의 단축어(`MworagoShortcuts`)가 보여 주는 이름이다.
    private static let steps = [
        "설정 앱에서 「동작 버튼」을 열어요.",
        "옆으로 넘겨 「단축어」에 두고, 단축어를 고르는 칸을 눌러요.",
        "「뭐라고」의 「들린 대로 찾기」를 골라요.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                // 이 화면이 하려는 말 전부다. 아래는 그렇게 하는 법이다.
                VStack(alignment: .leading, spacing: 12) {
                    Text("앱을 열지 않고 찾을 수 있어요.\n보던 영상은 그대로 두고요.")
                        .font(Theme.korean(.title))
                        .foregroundStyle(Theme.ink)
                    Text("동작 버튼을 길게 누르면 입력칸이 바로 떠요. 들린 대로 치면 뜻이 작은 창으로 와요.")
                        .font(Theme.korean(.body))
                        .foregroundStyle(Theme.grey1)
                        .lineSpacing(3)
                }
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Theme.blockGap) {
                    SectionLabel(title: "동작 버튼에 걸기")
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                // 뜻 번호(`1.` `2.`)와 같은 꼴로 단다.
                                Text("\(index + 1).")
                                    .font(Theme.korean(.body))
                                    .foregroundStyle(Theme.grey2)
                                    .monospacedDigit()
                                Text(step)
                                    .font(Theme.korean(.body))
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                // **동작 버튼이 없는 기종도 길이 있다.** 같은 동작이 단축어 앱에 이미 올라
                // 있으므로 그 자리로 보낸다. `ShortcutsLink` 는 단축어 앱의 이 앱 자리를 연다.
                VStack(alignment: .leading, spacing: Theme.blockGap) {
                    SectionLabel(title: "동작 버튼이 없으면")
                    Text("단축어 앱의 「뭐라고」 칸에 「들린 대로 찾기」가 있어요. 눌러도 같은 입력칸이 떠요.")
                        .font(Theme.korean(.body))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                }

                // 작은 창의 뜻이 어디서 오는지. 낱말은 앱 안 사전이 바로 주지만, 문장은
                // 화면 없이 번역기를 여는 문이 iOS 26 에 생겨서 그 아래에서는 비어 나온다
                // (`QuickLookup.translate`). 비었을 때 놀라지 않게 미리 적는다.
                Text("""
                    낱말 뜻은 앱 안 사전에서 바로 나와요.
                    문장 뜻은 iOS 26 부터 이 창에 나와요.
                    """)
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .readingPage(top: Theme.screenTop)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.paper)
        .koreanNavigationTitle("앱을 열지 않고 찾기")
    }
}

/// 찾기 화면에서 시트로 열 때. 내비게이션 바와 닫기 단추를 씌운다.
struct QuickFindGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            QuickFindGuide()
                .closeToolbar { dismiss() }
        }
    }
}

/// 찾기 화면의 빈자리에 한 번 뜨는 쪽지(`QuickFindTip`).
///
/// **안내문보다 낮게 선다.** 이 화면의 말은 "일본어를 들리는 대로 쳐보세요" 하나이고,
/// 이 쪽지는 그 곁에 붙는 덧말이다. 그래서 면(`grey4`) 하나에 글 두 줄만 싣고,
/// 크기는 본문 아래로 둔다.
struct QuickFindTipCard: View {
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("앱을 열지 않고도 찾을 수 있어요")
                        .font(Theme.korean(.body))
                        .foregroundStyle(Theme.ink)
                    Text("동작 버튼에 걸어 두면 길게 누르는 것만으로 입력칸이 떠요.")
                        .font(Theme.korean(.sub))
                        .foregroundStyle(Theme.grey2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(Theme.icon(.chevron))
                    .foregroundStyle(Theme.grey2)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 14)
        .background(Theme.grey4, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 24)
    }
}
