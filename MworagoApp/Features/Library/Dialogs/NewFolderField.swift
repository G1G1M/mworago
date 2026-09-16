import SwiftUI

/// 담기 판의 새 묶음. 접혀 있을 때는 한 줄, 펼치면 그 자리가 이름 받는 칸이 된다.
///
/// **만들면 그 자리가 골라진다.** 담기는 아래 `저장` 이 한다 — 여기서 곧바로
/// 담아 버리면 판에 `저장` 을 두고도 어떤 길로는 그것을 건너뛰게 되어,
/// 같은 화면이 두 가지 문법으로 도는 셈이 된다.
/// 담을 것 없이 자리만 만드는 일은 책장에서 한다.
///
/// 이름과 초점은 **담기 판이 쥔다.** 만든 뒤 칸을 비우고 초점을 놓는 일은 판이 고른 자리를
/// 바꾸는 일과 한 몸이라, 칸이 제 상태를 따로 들고 있으면 둘이 어긋난다.
struct NewFolderField: View {
    /// 이름을 받는 중인가. 접으면 `새 묶음 만들기` 한 줄로 돌아간다.
    @Binding var naming: Bool
    @Binding var name: String
    var focused: FocusState<Bool>.Binding
    /// 접을 수 있는가. 묶음이 하나도 없으면 접을 자리가 없다 — 그때는 이름을 짓는 것이
    /// 이 판에서 할 수 있는 유일한 일이다.
    let canFold: Bool
    /// 이름을 받아 그 자리를 고른다. 담기는 판의 `저장` 이 한다.
    let onCreate: () -> Void

    /// 줄 하나의 높이.
    ///
    /// **접힌 줄과 펼친 줄이 같은 높이여야 한다.** 판은 화면 한가운데 서므로 안이
    /// 자라면 위아래로 함께 벌어진다 — `새 묶음 만들기` 를 누르는 순간 판 전체가
    /// 들썩이고 아래 단추가 제자리를 옮긴다. 누른 것은 줄 하나인데 화면이 통째로
    /// 움직이는 셈이다. 두 상태를 같은 높이에 묶어 그 일이 아예 안 일어나게 한다.
    private static let rowHeight: CGFloat = 45

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if naming {
            // **한 줄에 담는다.** 칸 아래에 단추 둘을 세우면 그 `그만두기` 가 판 아래의
            // `그만두기` 와 나란히 서서, 어느 것이 무엇을 무르는지 알 수 없게 된다.
            // 여기서 무르는 것은 "이름 짓기를 접는" 작은 일이라 작은 자리에 둔다.
            HStack(spacing: 8) {
                TextField("예) 일상생활", text: $name)
                    .font(Theme.korean(.body))
                    .foregroundStyle(Theme.ink)
                    .textFieldStyle(.plain)
                    .focused(focused)
                    .submitLabel(.done)
                    .onSubmit { onCreate() }
                    .padding(.horizontal, 14)
                    .frame(height: Self.rowHeight - 6)
                    .background(Theme.grey4, in: RoundedRectangle(cornerRadius: 10))

                // **검게 채우지 않는다.** 이 판에서 검게 채워지는 것은 아래 `저장` 하나다.
                // 만들기는 고를 자리를 하나 늘리는 일이고, 담는 것은 여전히 `저장` 이다.
                Button { onCreate() } label: {
                    Text("만들기")
                        .font(Theme.korean(.body))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 15)
                        .frame(height: Self.rowHeight - 6)
                        .overlay(Capsule().strokeBorder(Theme.grey3, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.4 : 1)

                if canFold {
                    Button {
                        naming = false
                        focused.wrappedValue = false
                        name = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.grey2)
                            .frame(width: 28, height: Self.rowHeight - 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("이름 짓기 그만두기")
                }

            }
            .padding(.horizontal, 20)
            .frame(height: Self.rowHeight)
            .onAppear { focused.wrappedValue = true }
        } else {
            Button {
                naming = true
                focused.wrappedValue = true
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 16)
                    Text("새 묶음 만들기")
                        .font(Theme.korean(.body))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Theme.grey1)
                .padding(.horizontal, 20)
                .frame(height: Self.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
