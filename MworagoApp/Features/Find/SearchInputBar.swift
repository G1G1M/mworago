import SwiftUI

/// 찾기의 입력 바 — 떠 있는 컨트롤이라 유리를 쓴다.
///
/// **화면에 하나뿐이고 찾기 화면이 늘 같은 자리에 세운다.** 답이 있을 때와 없을 때
/// 따로 만들면 첫 글자를 치는 순간 칸이 헐리고 다시 서면서 초점이 풀린다 — 까닭은
/// `SearchView` 의 `body` 에 적어 두었다. 그래서 친 글자와 초점은 찾기 화면이 쥐고,
/// 이 바는 그리는 일만 한다.
struct SearchInputBar: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    /// 지운다. 검색을 비우는 일까지 찾기 화면이 한다.
    let onClear: () -> Void
    /// 한글로 치는 법을 편다.
    let onGuide: () -> Void

    var body: some View {
        VStack(spacing: 10) {

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.grey2)
                TextField("콘니치와", text: $text)
                    .font(Theme.korean(.field))
                    .foregroundStyle(Theme.ink)
                    .focused(focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !text.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.grey3)
                    }
                    .buttonStyle(.plain)
                }
                // 입력에 대한 도움말이라 입력 곁에 둔다. 표준 기호를 그대로 쓰고 색만 맞춘다.
                Button(action: onGuide) {
                    Image(systemName: "info.circle").foregroundStyle(Theme.grey2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("한글로 치는 법")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassSurface(cornerRadius: Theme.Radius.bar)
            // 스플래시가 마지막에 여기로 와서 앉는다. 화면 좌표로 올려야
            // 스플래시가 제 좌표계로 옮겨 쓸 수 있다.
            .background {
                GeometryReader { bar in
                    Color.clear.preference(key: InputBarFrame.self,
                                           value: bar.frame(in: .global))
                }
            }
        }
        .frame(maxWidth: Theme.listWidth)
        // 떠 있는 바지만 가장자리는 글이 시작하는 자리에 맞춘다 — 혼자 4pt 밖으로
        // 나가 있으면 아래로 스크롤할 때 바깥선이 본문과 어긋나 보인다.
        .padding(.horizontal, Theme.gutter)
        // **바닥에서 띄운다.** 14pt 로 두었더니 아이폰에서 입력 바와 탭 알약이 한 덩어리로
        // 붙어 보였다. 아이패드는 탭바가 위로 갔지만 값을 되돌리지 않는다 —
        // 다른 화면이 바닥에 두는 값과 같아야 화면을 옮길 때 바닥선이 흔들리지 않는다.
        .padding(.bottom, Theme.screenBottom)
    }
}
