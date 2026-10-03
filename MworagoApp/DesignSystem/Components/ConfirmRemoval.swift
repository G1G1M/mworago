import SwiftUI

extension View {
    /// 되돌릴 수 없는 일을 하기 전에 한 번 묻는다.
    ///
    /// **지우는 것만 시스템 알림으로 묻는다.** 되돌릴 수 없는 일은 앱의 얼굴보다
    /// 사용자가 이미 아는 "정말요?" 얼굴이 낫다. 네 자리(책장 · 묶음에서 골라 지우기,
    /// 묶음 없애기, 낱말 하나 빼기)가 같은 꼴을 각자 적고 있었다 — 그만두는 단추의 이름과
    /// 자리가 한 군데만 달라져도 손이 헷갈린다.
    func confirmRemoval(_ title: String, isPresented: Binding<Bool>, action: String,
                        message: String, perform: @escaping () -> Void) -> some View {
        alert(title, isPresented: isPresented) {
            Button(action, role: .destructive, action: perform)
            Button("그만두기", role: .cancel) { }
        } message: {
            Text(message)
        }
    }
}
