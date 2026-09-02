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

            Button { isPresented = false } label: {
                Text("그만두기")
                    .font(Theme.korean(16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Theme.grey4, in: Capsule())
                    .foregroundStyle(Theme.grey1)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 14)
        }
        .padding(.vertical, 20)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(folderNames, id: \.self) { name in
                row(name: name, here: marksCurrent && name == current) { onPick(name) }
            }
            Divider().overlay(Theme.grey4).padding(.vertical, 5)
            // 묶음에서 빼기. 지우는 것이 아니라 **아직 안 넣은 것으로 되돌리는** 일이라
            // 책장에 그대로 남는다 — 이름이 그것을 말해 준다.
            row(name: "아직 안 넣은 것으로", here: marksCurrent && current == nil,
                dim: true) { onPick(nil) }
        }
    }

    private var head: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.korean(17))
                .foregroundStyle(Theme.ink)
            Text(hint)
                .font(Theme.korean(12))
                .foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    /// 묶음 한 줄. 담기 모달과 같은 문법이다 — 왼쪽 점이 **지금 있는 자리**를 가리킨다.
    private func row(name: String, here: Bool, dim: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button {
            action()
            isPresented = false
        } label: {
            HStack(spacing: 11) {
                Circle()
                    .strokeBorder(here ? Theme.ink : Theme.grey3, lineWidth: 1.5)
                    .background(Circle().fill(here ? Theme.ink : .clear).padding(3.5))
                    .frame(width: 16, height: 16)
                Text(name)
                    .font(Theme.korean(16))
                    .foregroundStyle(dim ? Theme.grey1 : Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 10)
                if here {
                    Text("지금")
                        .font(Theme.korean(11))
                        .foregroundStyle(Theme.grey2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 있던 자리로 다시 옮기는 것은 아무 일도 아니다. 막지는 않되 흐리게 둔다.
        .opacity(here ? 0.55 : 1)
        .accessibilityHint(here ? "지금 있는 자리입니다" : "")
    }
}
