import SwiftUI
import MworagoCore

/// 담긴 자리를 알리는 한 줄. 입력 바 바로 위에 선다 — 갈피표에서 눈이 옮겨 온
/// 자리이면서, 다음에 칠 자리이기도 하다.
///
/// **누르면 그 묶음이 열린다.** 어디에 담겼는지를 알려 주고 나면 다음에 하고 싶은
/// 일이 "가서 보기"인데, 그러려면 탭을 옮겨 목록에서 그 이름을 다시 찾아야 했다.
/// 이미 이름을 적어 둔 줄이 그 자리로 가는 문이 된다.
///
/// **머무는 시간은 짧다.** 알림이 사라지기를 기다리게 하지 않는다 — 누를 사람은
/// 뜨자마자 누르고, 안 누를 사람에게는 화면을 가리는 띠일 뿐이다.
struct SavedNotice: View {
    /// 방금 담은 곳.
    let saved: FolderRoute
    /// 누르면 그 묶음으로 건너간다.
    let onOpen: () -> Void
    /// 스스로 물러날 때. 줄을 치우는 일은 찾기 화면이 한다 — 줄이 설지 말지를 그쪽이 쥔다.
    let onExpire: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 6) {
                Text("「\(saved.title)」에 담았어요")
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey1)
                // 누를 수 있다는 것은 화살표가 말한다. 색은 쓰지 않는다 —
                // 이 앱에서 색으로 강조하는 자리가 없다.
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.grey2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Theme.grey4, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("「\(saved.title)」 묶음을 엽니다")
        // **스스로 물러난다.** 닫는 단추를 두면 알림 하나에 할 일이 하나 는다.
        .task(id: saved) {
            guard Self.pinned == nil else { return }
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            onExpire()
        }
    }

    /// `--saved[=이름]` 로 띄워 둔 줄. 이름을 안 적으면 아직 안 넣은 것이다.
    ///
    /// **값이 붙은 인자는 `has` 로 못 잡는다** — `--saved=…` 는 그 이름 그대로가
    /// 아니어서다. `--folder[=이름]` 이 둘을 함께 받는 것과 같은 문법으로 읽는다.
    static var pinned: FolderRoute? {
        let launch = LaunchOptions.current
        guard let name = launch.value(for: "saved") ?? (launch.has("saved") ? "" : nil)
        else { return nil }
        return FolderRoute(name: name.isEmpty ? nil : name)
    }
}
