import Foundation
@preconcurrency import Translation

/// 번역 세션에 줄을 물린다.
///
/// 세션을 여는 일은 `RootView` 가 한다 — 탭 바깥이라 화면이 물러날 일이 없고,
/// 그래서 세션도 취소되지 않는다. 여기서는 열린 세션 하나로 줄에 선 것을 옮기는 일만 한다.
enum TranslationRunner {
    /// 줄에 선 것을 받아 옮겨 준다. 줄이 끝나면(세션이 물러나면) 이 반복도 끝난다.
    nonisolated static func serve(_ session: TranslationSession, _ store: Translations) async {
        let requests = await store.openRequests()
        for await batch in requests {
            let asked = batch.map { TranslationSession.Request(sourceText: $0) }
            var responses = try? await session.translations(from: asked)
            if responses == nil {
                // **한 번은 더 물어본다.** 언어팩을 아직 내려받는 중이면 첫 물음이 빈손으로
                // 돌아온다. 그 한 번 때문에 문장이 영영 안 뜨는 것은 사용자가 알 길이 없다.
                try? await Task.sleep(for: .milliseconds(400))
                responses = try? await session.translations(from: asked)
            }
            guard let responses else {
                // **쉬었다가 다시 싣는다.** 언어팩을 내려받는 중이면 몇 초 뒤에 되는
                // 일이고, 쉬지 않고 물으면 되지도 않을 것에 줄이 붙들린다.
                // 몇 번까지 보낼지는 줄이 세고, 그 뒤에는 놓아준다.
                try? await Task.sleep(for: .seconds(2))
                _ = await MainActor.run { store.failed(batch) }
                continue
            }
            let pairs = responses.map { (source: $0.sourceText, target: $0.targetText) }
            await MainActor.run { store.receive(pairs) }
        }
    }
}
