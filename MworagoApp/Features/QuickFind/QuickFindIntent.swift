import AppIntents
import SwiftUI
import MworagoCore

/// 들린 대로 친 것을 앱을 열지 않고 찾는다.
///
/// 동작 버튼에 걸어 두면 길게 누르는 것만으로 입력칸이 뜬다 — 애니를 보다가 들린 말을
/// 앱을 찾아 열고 탭을 고르는 사이에 잊지 않도록. 답은 작은 창 하나로 돌아오고,
/// 영상은 그대로 뒤에 있다.
///
/// 사전은 앱 안에 있으므로 여기서도 네트워크를 쓰지 않는다.
struct QuickFindIntent: AppIntent {

    static let title: LocalizedStringResource = "들린 대로 찾기"
    static let description = IntentDescription("들린 일본어를 한글로 치면 앱을 열지 않고 찾아 줘요.")

    /// **입력칸 안의 보기(`예) 콘니치와`)는 이름 자리에 둔다.** App Intents 에는 자리표시 글을
    /// 따로 받는 문이 없고, 시스템이 값을 물을 때 그 칸을 이름으로 채워 두는 것을 빌린다.
    ///
    /// 키보드는 기본 자판으로 연다 — 그대로 두면 영문 자판(`asciiCapable`)이 떠서 한글을
    /// 치려면 한 번 바꿔야 한다. 고쳐 쓰기와 첫 글자 대문자도 끈다. 들린 소리를 받아 적는
    /// 칸이라 맞춤법으로 고치면 오히려 틀린다.
    @Parameter(title: "예) 콘니치와",
               inputOptions: String.IntentInputOptions(keyboardType: .default,
                                                       capitalizationType: .none,
                                                       autocorrect: false),
               requestValueDialog: IntentDialog("일본어를 들린 대로 쳐 보세요"))
    var typed: String

    /// **읽어 줄 말(dialog)은 싣지 않는다.** 함께 실으면 시스템이 그 글을 창 위에 한 번 더
    /// 적어서, 뜻이 위아래로 두 번 보인다.
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let result = try await QuickLookup.shared.look(typed)
        return .result(view: QuickAnswerView(result: result))
    }
}

/// 작은 창의 소리 단추가 부른다. 되살린 원문을 일본어로 읽어 준다.
///
/// 단축어 목록에는 내놓지 않는다 — 창 안에서만 쓰는 손잡이다.
///
/// **`AudioPlaybackIntent` 로 둔다.** 그냥 `AppIntent` 로 두면 앱이 화면 없이 깨어 있는
/// 동안 오디오 세션을 켜지 못해 소리가 안 날 수 있다 — 위젯의 동작에서 같은 실패가
/// 보고됐고, 이 갈래로 바꿔 풀렸다(개발자 포럼 736445).
struct SpeakSentenceIntent: AudioPlaybackIntent {

    static let title: LocalizedStringResource = "소리 듣기"
    static let isDiscoverable = false

    @Parameter(title: "읽을 말")
    var text: String

    init() {}
    init(text: String) { self.text = text }

    @MainActor
    func perform() async throws -> some IntentResult {
        await SystemSpeaker.shared.speakToEnd(text, pace: .of(text))
        return .result()
    }
}

/// 동작 버튼 · 단축어 · Spotlight 에 따로 설정하지 않아도 앱의 이름으로 뜨게 한다.
struct MworagoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: QuickFindIntent(),
                    phrases: ["\(.applicationName)로 찾기",
                              "\(.applicationName)에서 찾기"],
                    shortTitle: "들린 대로 찾기",
                    systemImageName: "magnifyingglass")
    }
}
