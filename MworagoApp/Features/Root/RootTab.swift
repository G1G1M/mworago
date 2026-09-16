import MworagoCore

extension RootView {
    /// 탭 다섯. 탭바에 선 차례 그대로다.
    enum RootTab: Hashable {
        case find, library, practice, kana, settings

        init(_ launch: LaunchOptions) {
            switch launch.value(for: "tab") {
            // 탭을 합치기 전 이름으로 띄우던 스크립트가 있어 옛 이름도 받는다.
            case "library", "collection", "book": self = .library
            case "practice": self = .practice
            case "kana": self = .kana
            case "settings": self = .settings
            default: self = .find
            }
        }
    }
}
