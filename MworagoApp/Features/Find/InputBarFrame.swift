import SwiftUI

/// 입력 바가 실제로 놓인 자리.
///
/// **스플래시가 이것을 받아 마지막 알약을 앉힌다.** 전에는 스플래시가 제 숫자를 들고
/// 있었다 — 높이 52, 아래 여백 70. 둘 다 시뮬레이터 하나에서 눈으로 잰 값이라,
/// 폰트가 조금 다르게 그려지거나 탭바 높이가 다른 기기·방향으로 가면 마지막 한 프레임에서
/// 툭 튄다. 그 한 프레임이 "이것이 저것이 되었다"는 말을 통째로 무너뜨린다.
///
/// 재는 대신 **묻는다.** 진짜 입력 바만이 제 자리를 안다.
struct InputBarFrame: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}
