import SwiftUI

/// 앞뒤가 있는 카드. 눌러 뒤집으면 **정말로 돈다.**
///
/// **말과 그림이 어긋나 있었다.** 단추에는 `뒤집기` 라고 적혀 있는데 하는 일은 아래에
/// 답을 나타내는 것이었다. 카드라는 물건을 이미 그려 두고도 그것이 돌지 않으면,
/// 그 네모는 카드가 아니라 그냥 배경이다. 뒤집는 몸짓은 이 화면이 하는 일
/// (떠올렸다가 확인한다)과 정확히 같은 모양이라, 말을 바꾸는 것보다 그림을 맞추는 편이 낫다.
///
/// **각도를 애니메이션이 물고 있어야 면이 제때 갈린다.** `revealed` 같은 참·거짓으로
/// 면을 고르면 그 값은 처음부터 바뀌어 있어서, 돌기 시작하는 순간 이미 뒷면이 보인다.
/// `Animatable` 로 각도 자체를 받으면 `body` 가 **도는 중의 값**으로 다시 그려지므로,
/// 90도를 지나는 자리에서 앞뒤를 갈아 끼울 수 있다.
///
/// 뒷면은 미리 180도 돌려 둔다 — 안 그러면 뒤집힌 글자가 거울처럼 좌우로 뒤집혀 보인다.
struct FlipCard<Front: View, Back: View>: View, Animatable {
    /// 지금 돌아간 각도. 0 이면 앞면, 180 이면 뒷면이다.
    var angle: Double
    @ViewBuilder let front: () -> Front
    @ViewBuilder let back: () -> Back

    /// **`nonisolated` 여야 한다.** `View` 는 메인 액터에 매여 있는데 `Animatable` 의
    /// 요구는 그렇지 않아서, 그냥 두면 Swift 6 이 "액터를 넘나든다"며 막는다.
    /// 값 하나를 읽고 쓰는 일이라 넘나들어도 다툴 것이 없다.
    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    /// **동작 줄이기를 켠 사람에게는 돌리지 않는다.** 3D 회전은 어지럼을 부르는 축이라
    /// 시스템이 줄이라고 말해 둔 자리다. 그때는 돌리는 대신 그 자리에서 갈아 끼운다 —
    /// 보이는 내용은 같고 움직임만 빠진다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsBack: Bool { angle >= 90 }

    var body: some View {
        ZStack {
            // 앞뒤를 겹쳐 둔다. **높이가 둘 중 큰 쪽으로 굳으므로** 뒤집는 순간 카드가
            // 늘었다 줄었다 하지 않는다 — 그러면 아래 단추가 따라 밀린다.
            front()
                .opacity(showsBack ? 0 : 1)
                .accessibilityHidden(showsBack)
            back()
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showsBack ? 1 : 0)
                .accessibilityHidden(!showsBack)
        }
        .rotation3DEffect(.degrees(reduceMotion ? 0 : angle),
                          axis: (x: 0, y: 1, z: 0),
                          perspective: 0.32)
    }
}

enum Flip {
    /// 뒤집을 때 쓰는 결. **두 화면이 같은 값을 쓴다** — 연습 카드와 글자 익히기가
    /// 하는 일이 같으므로 손이 배우는 것도 같아야 한다.
    ///
    /// 0.42초는 한 바퀴 도는 것이 눈에 보이되 기다린다는 느낌은 없는 자리다.
    /// 끝에서 살짝 튀는 것은 종이 카드가 놓이는 결로 읽힌다.
    static let motion: Animation = .snappy(duration: 0.42, extraBounce: 0.08)
}
