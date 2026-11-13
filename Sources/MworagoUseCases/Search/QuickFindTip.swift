import Foundation
import MworagoDomain

/// 찾기 화면에 한 번만 뜨는 쪽지 — 앱을 열지 않고 찾는 길(동작 버튼)이 있다는 것.
///
/// **처음 온 사람에게는 띄우지 않는다.** 이 길이 좋은 까닭은 "앱을 찾아 열고 탭을 고르는
/// 사이에 소리를 잊는다"는 것인데, 아직 한 번도 안 찾아 본 사람은 그 수고를 모른다.
/// 몇 번 찾아 보고 나서야 그 말이 들린다. 그래서 찾은 것을 세어 `threshold` 에 닿으면 띄운다.
///
/// **닫으면 다시는 안 뜬다.** 안내 화면을 열어 본 것도 닫은 것으로 친다 — 읽은 사람에게
/// 같은 쪽지를 또 내밀 까닭이 없다. 설정에 같은 안내가 늘 있으므로 다시 찾아갈 길은 남는다.
public enum QuickFindTip {
    /// 몇 번 찾았는지 적는 이름.
    public static let countKey = "quickfind-tip-finds"
    /// 닫았다는 표시.
    public static let doneKey = "quickfind-tip-done"
    /// 몇 번 찾고 나서 띄우는가.
    public static let threshold = 3

    /// 찾은 것이 하나 늘었다. 이미 닫았거나 셀 만큼 셌으면 더 적지 않는다.
    public static func noteFind(in preferences: some PreferenceStoring) {
        guard !preferences.isMarked(doneKey) else { return }
        let count = finds(in: preferences)
        guard count < threshold else { return }
        preferences.set(String(count + 1), forKey: countKey)
    }

    /// 지금 띄울 때인가.
    public static func isDue(in preferences: some PreferenceStoring) -> Bool {
        !preferences.isMarked(doneKey) && finds(in: preferences) >= threshold
    }

    /// 닫는다. 센 것은 더 쓸 데가 없으므로 지운다.
    public static func dismiss(in preferences: some PreferenceStoring) {
        preferences.mark(doneKey)
        preferences.set(nil, forKey: countKey)
    }

    private static func finds(in preferences: some PreferenceStoring) -> Int {
        Int(preferences.string(forKey: countKey) ?? "") ?? 0
    }
}
