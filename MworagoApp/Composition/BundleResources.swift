import Foundation
import MworagoCore

/// 앱 번들에서 자원을 찾는다.
///
/// **이 한 타입만 `Bundle.main` 을 안다.** 예전에는 검색기가 직접 번들을 뒤졌는데,
/// 그러면 재료를 여는 길이 앱 안에서만 밟혀서 시험할 수가 없었다. 번들을 아는 자리를
/// 여기 하나로 좁혀 두면, 나머지는 "자원이 어디 있는지 대답하는 것"만 받으면 된다.
struct BundleResources: ResourceLocating {
    /// 어느 번들에서 찾을지. 기본은 앱의 것이다.
    var bundle: Bundle = .main

    func path(forResource name: String, ofType ext: String) -> String? {
        bundle.path(forResource: name, ofType: ext)
    }
}
