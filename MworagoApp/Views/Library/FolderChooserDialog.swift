import SwiftUI

/// 어디로 옮길지 고르는 판.
///
/// **담기 모달과 하는 일이 같지만 손에 든 것이 다르다.** 그쪽은 낱말 하나를 들고 와서
/// 만들면 곧 담기지만, 여기는 이미 담아 둔 것 여럿을 옮기는 자리다 — 그래서 만드는 길을
/// 두지 않는다. 자리를 먼저 만들고 싶으면 책장에서 만들면 되고, **빈 묶음이 남아 있으므로**
/// 만들어 둔 자리가 여기 그대로 보인다.
struct FolderChooserDialog: View {
    let title: String
    let hint: String
    /// 고를 수 있는 묶음들.
    let folderNames: [String]
    /// 지금 있는 자리. 점이 찍히고, 눌러도 달라질 것이 없으므로 흐리게 둔다.
    let current: String?
    /// 지금 자리를 표시할 것인가.
    ///
    /// **여러 묶음에서 골라 왔으면 "지금"이 하나가 아니다.** 책장의 `모두` 목록에서
    /// 고르면 서로 다른 묶음의 낱말이 섞이는데, 그때 아무 자리에나 점을 찍으면
    /// 있지도 않은 사실을 적는 것이 된다.
    var marksCurrent = true
    @Binding var isPresented: Bool
    var onPick: (String?) -> Void

    /// 지금 고른 자리. **담기 판과 같은 문법이다** — 줄을 누르면 골라지기만 하고,
    /// 옮기는 것은 `저장` 이 한다. 누르는 순간 옮겨지던 때는 점이 "지금 있는 자리"와
    /// "고른 것" 둘을 한꺼번에 뜻해서, 이미 찍힌 줄을 다시 눌러야 하는 화면이었다.
    /// **`아직 안 고름`이 따로 있어야 한다.** 여러 묶음에서 골라 왔으면 열 때 놓을
    /// 자리가 없는데(`marksCurrent` 가 꺼진다), 그것을 `none`(아직 안 넣은 것으로)과
    /// 같은 값으로 두면 아무것도 안 고른 사람이 낱말을 묶음 밖으로 빼게 된다.
    enum Pick: Equatable {
        case folder(String)
        case none
        case unset
        var name: String? { if case .folder(let n) = self { n } else { nil } }
    }
    @State private var picked: Pick = .unset

    /// 저장이 할 일이 있는가. 아직 안 골랐거나 있던 자리 그대로면 없다.
    private var canSave: Bool {
        switch picked {
        case .unset: false
        case .none: !(marksCurrent && current == nil)
        case .folder(let name): !(marksCurrent && name == current)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            // **줄이 적으면 스크롤을 두지 않는다.** `ScrollView` 는 준 높이를 늘 다
            // 차지해서, 묶음이 둘뿐인데도 판 아래가 그 높이만큼 비어 보인다.
            if folderNames.count > 5 {
                ScrollView { rows }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(height: 264)
            } else {
                rows
            }

            HStack(spacing: 10) {
                // 있던 자리 그대로면 옮길 것이 없다. 막아 두면 "무엇이 달라지는가"를
                // 단추가 대신 말해 준다.
                Button {
                    onPick(picked.name)
                    isPresented = false
                } label: {
                    Text("저장")
                        .font(Theme.korean(.body))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.ink, in: Capsule())
                        .foregroundStyle(Theme.paper)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)

                Button { isPresented = false } label: {
                    Text("그만두기")
                        .font(Theme.korean(.body))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.grey4, in: Capsule())
                        .foregroundStyle(Theme.grey1)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
        }
        .padding(.vertical, 20)
        // 열 때는 지금 있는 자리에 놓는다. 여러 묶음에서 골라 왔으면 지금이 하나가
        // 아니므로(`marksCurrent`) 아무 데도 안 놓는다.
        .onAppear { picked = marksCurrent ? (current.map(Pick.folder) ?? .none) : .unset }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(folderNames, id: \.self) { name in
                row(name: name, picked: picked == .folder(name),
                    here: marksCurrent && name == current) { picked = .folder(name) }
            }
            Theme.rule(Theme.grey4)
                .padding(.horizontal, 20)
                .padding(.vertical, 5)
            // 묶음에서 빼기. 지우는 것이 아니라 **아직 안 넣은 것으로 되돌리는** 일이라
            // 책장에 그대로 남는다 — 이름이 그것을 말해 준다.
            row(name: "아직 안 넣은 것으로", picked: picked == .none,
                here: marksCurrent && current == nil,
                dim: true) { picked = .none }
        }
    }

    private var head: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.korean(.title))
                .foregroundStyle(Theme.ink)
            Text(hint)
                .font(Theme.korean(.sub))
                .foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    /// 묶음 한 줄. 담기 모달과 같은 문법이다 — 왼쪽 점이 **지금 고른 자리**를 가리키고,
    /// 오른쪽 `지금` 이 **원래 있던 자리**를 말한다. 둘을 갈라 두어야 무엇이 달라지는지가
    /// 화면에 남는다.
    private func row(name: String, picked: Bool, here: Bool, dim: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Circle()
                    .strokeBorder(picked ? Theme.ink : Theme.grey3, lineWidth: 1.5)
                    .background(Circle().fill(picked ? Theme.ink : .clear).padding(3.5))
                    .frame(width: 16, height: 16)
                Text(name)
                    .font(Theme.korean(.body))
                    .foregroundStyle(dim ? Theme.grey1 : Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 10)
                if here {
                    Text("지금")
                        .font(Theme.korean(.tag))
                        .foregroundStyle(Theme.grey2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(picked ? [.isSelected] : [])
        .accessibilityHint(here ? "원래 있던 자리입니다" : "")
    }
}
