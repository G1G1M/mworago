import SwiftUI

/// 묶음 이름을 받는 판 — **만들 때도 고칠 때도 같은 화면이다.**
///
/// 시스템 알림으로 받다가, 시트로 갔다가, 여기로 왔다. 알림은 **몸짓이 맞았고**
/// (화면을 넘기는 것이 아니라 지금 화면에 묻는 일이다) **얼굴이 틀렸다**
/// (글자도 단추도 이 앱의 것이 아니다). 그래서 몸짓만 가져오고 얼굴은 앱의 것으로 짓는다 —
/// 종이 바닥 · 알약 단추 · **검게 채워지는 것은 지금 누를 것 하나.**
///
/// **없애기는 시스템 알림에 그대로 둔다.** 그것은 되돌릴 수 없는 일이라, 앱의 얼굴보다
/// 시스템이 늘 쓰는 얼굴로 묻는 편이 낫다 — 사용자가 이미 아는 "정말요?" 다.
struct FolderNameDialog: View {
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
    /// 이 판이 떠 있는가. **`@Environment(\.dismiss)` 를 쓰지 않는다** —
    /// 이것은 시트가 아니라 화면 위에 덧그린 판이라, 그 길로 닫으면 판이 아니라
    /// **이 판을 띄운 화면**이 닫힌다.
    @Binding var isPresented: Bool
    var onConfirm: (String) -> Void
    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var duplicate: Bool { existing.contains(trimmed) }
    /// 눌러도 아무 일이 없는 단추는 눌리지 않게 둔다 — 눌러 보고 알게 하지 않는다.
    private var blocked: Bool { trimmed.isEmpty || (duplicate && !mergesOnDuplicate) }

    var body: some View {
        // 판의 폭과 바닥은 `Dialog` 가 정한다. 여기서는 그 안에 무엇이 서는지만 적는다 —
        // 그래야 이름 받는 판과 할 일을 고르는 판이 같은 크기로 뜬다.
        VStack(alignment: .leading, spacing: 0) {
            head
            field
            buttons
        }
        .padding(.vertical, 20)
        .onAppear {
            name = initialName
            // **판이 먼저 앉고 나서 키보드를 올린다.** 같이 올라오면 판이 떠오르는
            // 몸짓과 화면이 밀려 올라가는 몸짓이 한 프레임에 겹쳐, 둘 다 뜬 것이
            // 아니라 화면이 한 번 튄 것으로 보인다.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                focused = true
            }
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
        .padding(.horizontal, 20)
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

            Button(action: close) {
                Text("그만두기")
                    .font(Theme.korean(16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Theme.grey4, in: Capsule())
                    .foregroundStyle(Theme.grey1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func confirm() {
        guard !blocked else { return }
        onConfirm(trimmed)
        close()
    }

    /// 판을 닫는다.
    ///
    /// **키보드를 먼저 내려보내고 한 박자 뒤에 판을 없앤다.** 한 번에 처리하면 초점을
    /// 놓았다는 것이 UIKit 에 닿기 전에 글 칸이 화면에서 사라지고, 그러면 키보드가
    /// 미끄러져 내려가는 대신 **애니메이션 없이 툭 꺼진다** — 판이 지는 것과 화면이
    /// 내려앉는 것이 한 프레임에 겹쳐 보이던 까닭이 이것이다.
    private func close() {
        focused = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            isPresented = false
        }
    }
}
