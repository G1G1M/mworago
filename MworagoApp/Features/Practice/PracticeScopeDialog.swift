import SwiftUI
import MworagoCore

/// 무엇을 연습할지 고르는 판.
///
/// **옮기는 판과 하는 일이 다르다.** `FolderChooserDialog` 는 낱말을 다른 자리로
/// 보내는 일이라 `저장` 으로 한 번 더 묻지만, 여기서 고르는 것은 **지금 볼 것**이다 —
/// 되돌릴 것이 없으므로 누르는 즉시 정해지고 판이 진다. 목록에서 보기를 바꾸는 것과
/// 같은 결이다.
///
/// **비어 있는 묶음은 줄에 없다.** 골라 봐야 카드가 한 장도 없는 화면으로 가는데,
/// 그 화면에는 다시 고를 단추가 없다.
struct PracticeScopeDialog: View {
    /// 고를 수 있는 묶음들. (이름, 낱말 수) — 이름이 `nil` 이면 아직 안 넣은 것이다.
    let folders: [(route: FolderRoute, count: Int)]
    /// 모은 것 전체의 낱말 수.
    let total: Int
    /// 지금 보고 있는 것. `nil` 이면 전체다.
    let current: FolderRoute?
    @Binding var isPresented: Bool
    var onPick: (FolderRoute?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DialogHead(title: "무엇을 연습할까요?", hint: "고른 묶음만 넘겨 봐요.")
            // 줄이 적으면 스크롤을 두지 않는다 — `ScrollView` 는 준 높이를 늘 다 차지해서
            // 묶음이 둘뿐인데도 판 아래가 그 높이만큼 비어 보인다.
            if folders.count > 4 {
                ScrollView { rows }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(height: 264)
            } else {
                rows
            }

            DialogButton(title: "그만두기") { isPresented = false }
                .padding(.horizontal, 20)
                .padding(.top, 14)
        }
        .padding(.vertical, 20)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(name: "전체", count: total, picked: current == nil) { pick(nil) }
            DialogDivider()
            ForEach(folders, id: \.route.id) { folder in
                row(name: folder.route.title, count: folder.count,
                    picked: current == folder.route,
                    dim: folder.route.name == nil) { pick(folder.route) }
            }
        }
    }

    private func pick(_ route: FolderRoute?) {
        onPick(route)
        isPresented = false
    }

    /// 묶음 한 줄. 왼쪽 점이 지금 보고 있는 것을 가리키고, 오른쪽에 몇 장인지가 선다 —
    /// 고르기 전에 알고 싶은 것이 그 수다.
    private func row(name: String, count: Int, picked: Bool, dim: Bool = false,
                     action: @escaping () -> Void) -> some View {
        RadioRow(title: name, isPicked: picked, dim: dim, action: action) {
            Text("\(count)개")
                .font(Theme.korean(.tag))
                .foregroundStyle(Theme.grey2)
                .monospacedDigit()
        }
    }
}
