import SwiftUI

/// 묶음 이름을 받는 자리 — **만들 때도 고칠 때도 같은 화면이다.**
///
/// 시스템 알림으로 받고 있었다. 알림은 어느 앱에서나 같은 얼굴이라 **그 순간만 남의
/// 앱이 된다** — 글자가 고운돋움이 아니고, 파란 글씨 단추와 굵은 제목은 이 앱 어디에도
/// 없는 문법이다. 담기 모달과 같은 꼴로 세운다: 종이 바닥 · 알약 단추 ·
/// **검게 채워지는 것은 지금 누를 것 하나.**
///
/// **없애기는 알림에 그대로 둔다.** 그것은 되돌릴 수 없는 일이라, 앱의 얼굴보다
/// 시스템이 늘 쓰는 얼굴로 묻는 편이 낫다 — 사용자가 이미 아는 "정말요?" 다.
struct FolderNameSheet: View {
    let title: String
    /// 제목 아래 한 줄. 이 자리에서 무슨 일이 일어나는지 말한다.
    let hint: String
    let placeholder: String
    /// 이미 있는 이름들. 같은 이름을 쳤을 때 무슨 일이 일어나는지 미리 말해 준다.
    var existing: [String] = []
    /// 같은 이름이면 합쳐지는가. 이름 바꾸기는 합쳐지고(막지 않는다 — 한 편을 두
    /// 이름으로 담아 둔 것을 합치는 일이 실제로 있다), 새로 만들기는 아무 일도 없다.
    var mergesOnDuplicate = false
    var confirmLabel = "만들기"
    var initialName = ""
    var onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var duplicate: Bool { existing.contains(trimmed) }
    /// 눌러도 아무 일이 없는 단추는 눌리지 않게 둔다 — 눌러 보고 알게 하지 않는다.
    private var blocked: Bool { trimmed.isEmpty || (duplicate && !mergesOnDuplicate) }

    var body: some View {
        // **담기 모달과 같은 껍데기다.** 안쪽 덩어리에만 종이를 깔면 시트가 그보다 클 때
        // 위아래로 남의 바닥이 드러나, 종이 카드가 회색 카드 안에 든 것처럼 보인다.
        // 스크롤 뷰가 시트를 꽉 채우고 그 위에 종이를 깐다.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                head
                field
                buttons
            }
            .frame(maxWidth: Theme.readWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, Theme.screenBottom)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.paper)
        .presentationDragIndicator(.visible)
        // **시트를 내용에 맞춘다.** 기본 폼 시트는 이름 한 줄 받는 자리에 화면 절반을
        // 내주어, 칠 것은 한 줄인데 빈 종이가 그 몇 배로 남는다.
        // detent 를 함께 걸지 않는다 — 높이를 정해 버리면 `fitted` 가 진다.
        .presentationSizing(.fitted)
        .onAppear {
            name = initialName
            focused = true
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
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    /// 이름 받는 칸. 담기 모달의 그것과 같은 꼴이라 눈이 두 번 배우지 않는다.
    private var field: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(placeholder, text: $name)
                .font(Theme.korean(16))
                .foregroundStyle(Theme.ink)
                .textFieldStyle(.plain)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { confirm() }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Theme.grey4, in: RoundedRectangle(cornerRadius: 10))

            // 같은 이름을 쳤을 때 **무슨 일이 일어나는지 미리 말한다.** 새로 만들기는
            // 아무 일도 없어서 단추가 안 눌리는 까닭이 보여야 하고, 이름 바꾸기는
            // 둘이 합쳐지는 것이 뜻한 일일 수도 아닐 수도 있다.
            if duplicate {
                Text(mergesOnDuplicate ? "이미 있는 묶음과 합쳐져요" : "이미 있는 묶음이에요")
                    .font(Theme.korean(12))
                    .foregroundStyle(Theme.grey2)
            }
        }
        .padding(.horizontal, Theme.gutter)
    }

    /// 두 단추.
    ///
    /// **이름 받는 칸과 같은 여백으로, 같은 폭 안에 선다.** 글자 수대로 폭을 잡으면
    /// `만들기` 와 `그만두기` 가 서로 다른 크기가 되고, 둘 다 칸보다 한참 좁아
    /// 시트 안에 크기가 세 가지 서게 된다. 세로 여백도 칸의 것을 그대로 쓴다.
    private var buttons: some View {
        HStack(spacing: 10) {
            Button(action: confirm) {
                Text(confirmLabel)
                    .font(Theme.korean(16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Theme.ink, in: Capsule())
                    .foregroundStyle(Theme.paper)
            }
            .buttonStyle(.plain)
            .disabled(blocked)
            .opacity(blocked ? 0.4 : 1)

            Button { dismiss() } label: {
                Text("그만두기")
                    .font(Theme.korean(16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Theme.grey4, in: Capsule())
                    .foregroundStyle(Theme.grey1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 16)
    }

    private func confirm() {
        guard !blocked else { return }
        onConfirm(trimmed)
        dismiss()
    }
}
