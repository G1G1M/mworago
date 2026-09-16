import SwiftUI

/// 내비 바에 뜨는 화면 이름을 **앱 서체로** 그린다.
///
/// `navigationTitle` 은 시스템이 제 글꼴(SF)로 그린다. 화면 안의 글은 모두 고운돋움인데
/// 맨 위 이름 하나만 다른 글씨면, 그 줄만 남의 화면에서 옮겨 온 것처럼 보인다.
///
/// **`navigationTitle` 도 함께 남긴다.** 눈에는 이 `principal` 이 보이지만, 뒤로 버튼이
/// 가져다 쓰는 이름은 여전히 `navigationTitle` 이다. 지우면 뒤로 버튼이 이름을 잃는다.
struct KoreanNavigationTitle: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(Theme.korean(.title, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
    }
}

extension View {
    /// 화면 이름을 앱 서체로 그린다. `navigationTitle` 대신 쓴다.
    func koreanNavigationTitle(_ title: String) -> some View {
        modifier(KoreanNavigationTitle(title: title))
    }
}
