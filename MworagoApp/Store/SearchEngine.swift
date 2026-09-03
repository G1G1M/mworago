import Foundation
import Observation
import MworagoCore

/// 사전을 열고 검색을 맡는다.
///
/// 무거운 일은 앱을 켤 때 한 번뿐이고, 그마저도 색인 파일이라 거의 즉시 끝난다
/// (XML 을 파싱하던 시절에는 3.1초였다).
///
/// **재료를 스스로 찾지 않는다.** 예전에는 이 자리에서 `Bundle.main` 을 뒤져
/// 사전 파일을 열었다. 그러면 이 클래스를 세우는 일이 곧 앱 번들을 세우는 일이 되어,
/// 시험이 한 줄도 닿지 못했다. 지금은 **어디서 찾을지**만 받는다
/// (`ResourceLocating`) — 앱은 번들을, 시험은 임시 자리를 준다.
@Observable
@MainActor
final class SearchEngine {

    private(set) var segments: [Segment] = []
    private(set) var isReady = false
    private(set) var failure: String?

    /// 사전 색인과 빈도표 한 벌. 열지 못했으면 `nil` 이고 `failure` 에 사정이 적힌다.
    private let lexicon: Lexicon?
    /// 조각을 찾아본 결과. **글자를 칠 때마다 다시 찾지 않으려고** 들고 있는다.
    private let cache = SearchCache()
    /// 돌고 있는 검색. 다음 글자가 들어오면 이것부터 물린다.
    private var searching: Task<Void, Never>?

    /// 앱이 쓰는 길. 번들에서 재료를 찾는다.
    convenience init() { self.init(locating: BundleResources()) }

    /// 자원 자리를 받아 연다. 시험은 임시 자리를 준다.
    init(locating locator: some ResourceLocating) {
        do {
            lexicon = try Lexicon(locating: locator)
            isReady = true
        } catch {
            lexicon = nil
            failure = String(describing: error)
        }
    }

    /// 이미 연 재료를 그대로 받는다. 미리보기와 시험이 파일을 거치지 않고 세울 때 쓴다.
    init(lexicon: Lexicon) {
        self.lexicon = lexicon
        isReady = true
    }

    /// 입력을 낱말로 나누고 각각을 찾는다. 띄어 쓰지 않아도 사전이 알아서 끊는다.
    ///
    /// **찾는 일은 화면 밖에서 한다.** 글자를 칠 때마다 이 자리에서 곧바로 찾고 있었는데,
    /// 열다섯 글자짜리 문장에서 한 글자에 1.6초가 걸렸다 — 그동안 화면이 멈춘다.
    /// 조각을 재어 두고(`cache`) 후보 자리를 줄여 그 시간을 크게 낮췄지만,
    /// 긴 입력의 첫 계산은 여전히 무거우므로 손이 멈추지 않도록 밖으로 내보낸다.
    func search(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // 다음 글자가 들어왔으면 앞 글자의 답은 이미 쓸모가 없다.
        searching?.cancel()
        guard let lexicon, !trimmed.isEmpty else {
            segments = []
            return
        }
        let cache = self.cache
        searching = Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) {
                Segmenter.segment(trimmed, in: lexicon.dictionary,
                                  frequency: lexicon.frequency, cache: cache)
            }.value
            guard !Task.isCancelled else { return }
            self?.segments = found
        }
    }

    /// 첫 글자를 칠 때 몰릴 일을 미리 해 둔다.
    ///
    /// 첫 글자에서만 걸린다는 것은 **그 순간에 처음 일어나는 일**이 있다는 뜻이다.
    /// 여기서는 셋이었다 — 색인 파일의 첫 조회(39MB 짜리라 읽을 페이지를 디스크에서
    /// 가져온다), 규칙표들의 첫 초기화(가나 표·활용 규칙은 처음 쓸 때 만들어진다),
    /// 그리고 조각 캐시가 통째로 비어 있는 것.
    ///
    /// 셋 다 한 번 겪고 나면 다시 겪지 않는다. 그러니 **손이 얹히기 전에** 겪어 둔다.
    /// 화면 밖에서 낮은 우선순위로 도므로 뜨는 데 걸리적거리지 않는다.
    func prewarm() {
        guard let lexicon else { return }
        let cache = self.cache
        Task.detached(priority: .utility) {
            // 한 글자면 충분하다. 색인·규칙표·캐시가 모두 한 번씩 지나간다.
            _ = Segmenter.segment("아", in: lexicon.dictionary,
                                  frequency: lexicon.frequency, cache: cache)
        }
    }

    /// 곧바로 찾아 결과까지 채운다.
    ///
    /// 화면 밖에서 결과가 그 자리에서 필요한 자리에만 쓴다 — 실행 인자로 화면을 세워
    /// 스크린샷을 찍을 때가 그렇다. 사람이 치는 길에서는 쓰지 않는다.
    func searchNow(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        searching?.cancel()
        guard let lexicon, !trimmed.isEmpty else {
            segments = []
            return
        }
        segments = Segmenter.segment(trimmed, in: lexicon.dictionary,
                                     frequency: lexicon.frequency, cache: cache)
    }
}
