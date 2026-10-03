import Foundation
@preconcurrency import Translation
import MworagoCore

extension Locale.Language {
    /// 번역기에 넘기는 말들. 찾기 화면과 화면 없이 찾는 자리가 같은 값을 쓴다.
    static let japanese = Locale.Language(identifier: "ja")
    static let english = Locale.Language(identifier: "en")
    static let korean = Locale.Language(identifier: "ko")
}

extension TranslationPack {
    /// 기기가 알려 준 언어팩 상태를 앱의 말로 옮긴다.
    ///
    /// `.supported` 는 "기기는 할 수 있는데 **언어팩을 아직 안 받았다**"는 뜻이다 —
    /// 그 상태에서는 문장 뜻이 한 줄도 안 뜨므로 받을 것이 있다고 말해야 한다.
    init(_ status: LanguageAvailability.Status) {
        self = switch status {
        case .installed: .ready
        case .supported: .needsDownload
        case .unsupported: .unsupported
        @unknown default: .unknown
        }
    }
}
