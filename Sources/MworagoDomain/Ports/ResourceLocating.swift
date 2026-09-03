import Foundation

/// 자원이 어디 있는지 대답하는 것.
///
/// **`Bundle.main` 을 직접 부르지 않기 위해 있다.** 예전에는 검색기가 스스로 번들을
/// 뒤져 사전 파일을 찾았는데, 그러면 그 길이 앱 안에서만 밟힌다 — 재료를 여는 일이
/// 잘못됐는지 시험할 방법이 없고, 화면을 세우지 않고는 검색기를 만들 수도 없다.
///
/// 무엇을 어디서 찾을지는 **부르는 쪽**이 정한다. 앱은 번들을 주고, 시험은 임시 자리를
/// 주고, 측정 도구는 작업 폴더를 준다.
public protocol ResourceLocating: Sendable {
    /// 없으면 `nil`. 있는지 없는지는 부르는 쪽이 판단한다.
    func path(forResource name: String, ofType ext: String) -> String?
}
