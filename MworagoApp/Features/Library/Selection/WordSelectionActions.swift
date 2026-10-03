import SwiftUI
import MworagoCore

extension View {
    /// 골라 둔 낱말로 하는 두 일 — 옮길 곳을 묻는 판과 지울지 묻는 알림.
    ///
    /// 책장의 `모두` 목록과 묶음 화면이 같은 판과 같은 알림을 각자 붙이고 있었다.
    /// 다른 것은 "지금 자리"를 무엇으로 찍느냐 하나다 — 묶음 화면은 그 묶음이고,
    /// 여러 묶음에서 골라 온 `모두` 목록은 고른 것이 다 같은 자리일 때만 찍는다.
    func wordSelectionActions(count: Int,
                              moving: Binding<Bool>,
                              removing: Binding<Bool>,
                              folderNames: [String],
                              current: String?,
                              marksCurrent: Bool = true,
                              onMove: @escaping (String?) -> Void,
                              onRemove: @escaping () -> Void) -> some View {
        dialog(isPresented: moving) {
            FolderChooserDialog(title: "어디로 옮길까요?",
                                hint: "고른 낱말 \(count)개가 한꺼번에 가요.",
                                folderNames: folderNames,
                                current: current,
                                marksCurrent: marksCurrent,
                                isPresented: moving,
                                onPick: onMove)
        }
        .confirmRemoval("고른 낱말을 지울까요?", isPresented: removing, action: "지우기",
                        message: "\(count)개를 책장에서 빼요. 되돌릴 수 없어요.",
                        perform: onRemove)
    }
}
