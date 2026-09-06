import SwiftUI
@preconcurrency import Translation
import MworagoCore

/// 탭 셋.
///
/// 앱의 이야기가 이 차례다 — 걸린 대사를 **찾고**, 찾은 것이 그 화의 **교재**가 되고,
/// 마지막에 **따라 말한다**. 그래서 탭 순서가 곧 사용자가 겪는 순서다.
///
/// 넷이던 것을 셋으로 줄였다. "모은 것"과 "도감"은 같은 낱말을 평평하게 보느냐
/// 날짜로 묶어 보느냐의 차이뿐이라 탭 두 칸을 쓸 일이 아니었고, 담기 전에는
/// **빈 화면이 셋**이라 처음 온 사람에게 같은 말을 세 번 했다.
///
/// 탭바는 표준 컨트롤을 그대로 쓰고 색만 맞춘다. 직접 그리면 시스템이 주는 것
/// (아이패드의 자리, 손대기 좋은 크기, 손쉬운 사용)을 전부 다시 만들어야 한다.
struct RootView: View {
    /// 옮기는 자리. 세션을 여기서 열어 두려고 받는다 — 까닭은 `translationSessions` 에 적었다.
    @Environment(TranslationDesk.self) private var desk
    /// 언어쌍마다 하나씩. 번역을 못 하는 기기에서는 만들지 않으므로 세션도 열리지 않는다 —
    /// 열어 두고 실패를 삼키면 애플이 대신 시트를 띄운다.
    @State private var fromJapanese: TranslationSession.Configuration?
    @State private var fromEnglish: TranslationSession.Configuration?
    /// 앱이 앞으로 돌아오는 것을 본다 — 언어팩을 받아 온 사람을 다시 확인하려고.
    @Environment(\.scenePhase) private var scenePhase

    /// 작은 값을 적어 두는 자리 — 모습 설정과 온보딩 표시가 쓴다.
    ///
    /// **화면이 파일을 몰라도 되게** 밖에서 받는다. 예전에는 두 값이 각자 뷰 파일 안에서
    /// `FileManager` 로 Application Support 를 찾았다.
    private let preferences: any PreferenceStoring
    /// 어느 탭을 열지 실행 인자로 고를 수 있다 (`--tab=collection`).
    /// `--query=` · `--select=` 와 같은 취지 — 시뮬레이터를 손으로 두드리면
    /// 엉뚱한 것을 누르기 쉽고, 무엇을 눌렀는지도 기록에 남지 않는다.
    /// 다른 탭에서 찾기로 넘기는 검색어.
    @State private var pendingQuery: String?
    /// 찾기 탭을 눌렀다는 신호. 찾기 화면이 받아서 입력 바에 손을 얹는다.
    /// 교재에서 하루치를 들고 연습으로 넘길 때 그 낱말들.
    @State private var practiceSubset: [CollectedWord]?
    @State private var practiceLabel: String?
    @State private var tab: RootTab = RootTab(LaunchOptions.current)
    /// 온보딩 시안 — 실행 인자로만 뜬다.
    /// 처음 열었는가. 봤으면 파일 하나가 남고 다시 나오지 않는다.
    /// `--onboarding` 으로는 봤는지와 무관하게 다시 띄운다.
    /// 앱을 밝게 볼지 어둡게 볼지 — 설정의 `모습`. 기본은 기기를 따르는 것이다.
    @State private var appearance: Appearance
    @State private var showOnboarding: Bool
    /// 앱을 여는 한 장. `--no-splash` 로 건너뛴다 — 다른 화면을 찍을 때마다
    /// 1초를 기다릴 이유가 없다. `--query=` · `--tab=` 과 같은 취지다.
    @State private var showSplash = !LaunchOptions.current.has("no-splash")
    /// 진짜 입력 바가 놓인 자리. 스플래시가 마지막에 여기로 와서 앉는다.
    ///
    /// 스플래시는 탭 화면 **위에** 얹혀 있으므로, 그 아래에서 찾기 화면이 이미 자리를
    /// 잡아 두었다. 그 자리를 그대로 받아 쓰면 기기와 방향이 달라져도 어긋나지 않는다.
    @State private var inputBarFrame: CGRect?

    /// 적어 둔 것을 읽어 첫 모습을 정한다. 기본값은 앱의 자리이고, 미리보기와
    /// 화면 확인은 아무것도 남기지 않는 판을 준다.
    init(preferences: any PreferenceStoring = FilePreferences()) {
        self.preferences = preferences
        _appearance = State(initialValue: Appearance.saved(in: preferences))
        _showOnboarding = State(initialValue:
            OnboardingSeen.forced || !preferences.isMarked(OnboardingSeen.key))
    }

    /// 낱말을 들고 찾기로 건너간다.
    private func goFind(_ hangul: String) {
        pendingQuery = hangul
        tab = .find
    }

    /// 하루치를 들고 연습으로 건너간다. 날짜는 그 화의 이름이므로 함께 넘긴다.
    private func goPractice(_ words: [CollectedWord]) {
        guard let first = words.first else { return }
        practiceSubset = words
        practiceLabel = first.collectedAt.formatted(.dateTime.month(.wide).day().locale(Theme.locale))
        tab = .practice
    }

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

    var body: some View {
        // **온보딩과 스플래시를 `overlay` 로 얹지 않는다.**
        //
        // `TabView` 에 `.overlay` 로 얹었더니 그 안의 것이 **두 번 그려졌다** —
        // 온보딩의 "건너뛰기"가 화면 위와 아래에 하나씩 섰다. 탭바를 품은 컨테이너가
        // 오버레이를 제 몫으로 한 번 더 그리는 탓이라, 사이즈 클래스를 되돌린 뒤에도 남았다.
        //
        // 덮는 것은 형제로 둔다. `ZStack` 은 차례대로 쌓을 뿐이라 두 번 그릴 일이 없고,
        // 위아래 관계(스플래시가 온보딩 위)도 적힌 차례 그대로다.
        ZStack {
            tabs

            // 처음 열었을 때 다섯 장 — 탭 하나에 한 장씩. 봤으면 다시 나오지 않는다.
            if showOnboarding {
                Onboarding(onDone: {
                    preferences.mark(OnboardingSeen.key)
                    withAnimation(.snappy(duration: 0.2)) { showOnboarding = false }
                })
                .transition(.opacity)
            }

            // **스플래시가 맨 위다.** 온보딩보다 앞에 두면 처음 여는 사람에게 온보딩이
            // 먼저 뜨고 그 위로 스플래시가 덮인다 — 순서가 뒤집힌다.
            if showSplash {
                // **온보딩이 뒤따르면 알약까지만 보인다.** 변신해 놓고 그 위를 온보딩이
                // 덮으면 아무도 못 본 변신이 되고, 이 장면이 하려는 말도 거짓이 된다.
                Splash(target: inputBarFrame, becomesInputBar: !showOnboarding, onDone: {
                    withAnimation(.easeOut(duration: 0.22)) { showSplash = false }
                })
                .transition(.opacity)
            }
        }
        .onPreferenceChange(InputBarFrame.self) { frame in
            if let frame { inputBarFrame = frame }
        }
        // **번역 세션을 탭 밖에 둔다.**
        //
        // 한때는 찾기 화면이 세션을 열었다. `.translationTask` 는 뷰가 물러나면 취소되는데,
        // **다시 들어와도 스스로 다시 돌지 않는다** — 설정 값이 바뀔 때만 도는 자리라
        // 탭을 다녀온 것은 설정에 아무 변화가 아니다. 그래서 찾기 탭을 한 번 벗어난 뒤로는
        // 어떤 문장도 옮겨지지 않았다. 줄(`TranslationQueue`)을 열 때마다 새로 내도록
        // 고쳤는데도 증상이 남은 것은 **줄을 다시 여는 사람이 없어서**였다.
        //
        // 여기는 탭 위가 아니라 탭 **바깥**이다. 화면이 물러날 일이 없으니 세션도 취소되지
        // 않고, 줄은 앱이 사는 동안 이어진다.
        //
        // 번역을 못 하는 기기에서는 설정을 만들지 않으므로 세션도 열리지 않는다 —
        // 열어 두고 실패를 삼키면 애플이 대신 시트를 띄운다.
        .task { await checkTranslation() }
        // **앞으로 돌아올 때 다시 묻는다.** 안내를 보고 설정 앱에서 언어팩을 받아 온
        // 사람에게, 그 사실이 화면에 닿는 자리가 여기밖에 없다.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await checkTranslation() }
        }
        .translationTask(fromJapanese) { session in
            await Self.serve(session, desk.japanese)
        }
        .translationTask(fromEnglish) { session in
            await Self.serve(session, desk.english)
        }
        .tint(Theme.ink)
        // **아직 여러 말로 옮기지 않았다.** 기기를 영어로 써도 화면은 한국어이므로
        // 날짜만 영어로 뜨면 안 된다. 여러 말을 받게 되면 이 줄을 걷어낸다.
        .environment(\.locale, Theme.locale)
        // 설정에서 고른 밝기. `nil` 이면 기기를 따른다.
        .preferredColorScheme(appearance.scheme)
    }

    /// 탭 다섯. `body` 에서 빼 둔 것은 덮는 것(온보딩 · 스플래시)과 형제로 세우기 위해서다.
    private var tabs: some View {
        // iOS 18 부터의 `Tab` 을 쓴다. 예전 `.tabItem` 은 호환 경로로 가면서
        // 아이패드에서 탭바가 위아래로 **두 번** 그려졌다.
        TabView(selection: $tab) {
            Tab(value: RootTab.find) {
                SearchView(incoming: $pendingQuery)
            } label: {
                Image(systemName: "magnifyingglass")
                    .accessibilityLabel("찾기")
            }
            Tab(value: RootTab.library) {
                LibraryView(onPick: goFind, onPractice: goPractice)
            } label: {
                Image(systemName: "books.vertical")
                    .accessibilityLabel("책장")
            }
            Tab(value: RootTab.practice) {
                PracticeView(subset: practiceSubset,
                             subsetLabel: practiceLabel,
                             onClearSubset: {
                                 practiceSubset = nil
                                 practiceLabel = nil
                             })
            } label: {
                // **소리가 아니라 카드다.** `waveform` 은 소리 파형이라 녹음·발음으로 읽힌다.
                // 이 탭이 하는 일은 담아 둔 낱말을 한 장씩 넘겨 보는 것이므로 카드 더미로 적는다.
                Image(systemName: "rectangle.stack")
                    .accessibilityLabel("연습")
            }
            // 글자는 낱말과 짝이다 — 글자는 마흔여섯 자로 끝나지만 낱말은 끝이 없다.
            // 연습 안의 쪽지였던 것을 여기로 올렸다. 가나를 못 읽어 멈추는 순간은
            // 찾을 때도 생기는데 쪽지로는 연습 화면에서만 닿았다.
            Tab(value: RootTab.kana) {
                KanaView()
            } label: {
                Image(systemName: "character.book.closed")
                    .accessibilityLabel("글자")
            }
            // 설정은 앱의 이야기(찾고·담기고·다시 만난다) 밖이지만 **어느 화면에서나
            // 닿아야 한다.** 교재 헤더에 두었더니 왜 거기에만 있는지 말할 수 없었다.
            Tab(value: RootTab.settings) {
                Settings(appearance: $appearance, preferences: preferences)
            } label: {
                Image(systemName: "gearshape")
                    .accessibilityLabel("설정")
            }
        }
        // 탭바에는 **아이콘만** 둔다. 다섯뿐이고 뜻이 분명한 기호라 이름이 없어도 읽히고,
        // 글자가 빠지면 그만큼 화면이 조용해진다. 이름은 손쉬운 사용에 남겨 두고,
        // 온보딩이 한 번 짚는다 — 다섯 장이 탭 하나씩을 맡고, 각 장 맨 위에 그 탭의
        // 아이콘과 이름이 나란히 선다. 눈으로 못 읽는 사람에게까지 아이콘만 주면
        // 그건 지운 것이 아니라 잃은 것이다.
        //
        // **탭바 자리는 시스템에 맡긴다.** 아이폰은 아래, 아이패드는 위(iPadOS 26 의
        // 떠 있는 알약)다. 한때 아이패드에서도 아래에 두려고 사이즈 클래스를 속였는데,
        // 그 대가로 화면이 두 벌 그려졌다 — 자세한 것은 `MworagoApp.swift` 에 적어 두었다.
        // **글은 전부 한국어다.** 기기 언어가 영어면 날짜만 "August 31"로 나와
        // 화면에서 그 한 줄만 남의 말이 된다. 이 앱이 쓰는 말로 고정한다.
        .environment(\.locale, Locale(identifier: "ko_KR"))
    }

    /// 옮길 수 있는 언어쌍인지 묻고, 세션 설정을 만든다.
    ///
    /// **묻고 나온 답을 버리지 않는다.** 예전에는 "못 하는 것만 아니면 된다"고 보고
    /// `.unsupported` 인지만 확인한 뒤 흘려보냈다. 그런데 `.supported` 는 "기기는 할 수
    /// 있는데 **언어팩을 아직 안 받았다**"는 뜻이라, 그 상태에서는 문장 뜻이 한 줄도
    /// 안 뜬다. 화면에는 아무 말이 없었고, 사용자가 보기에 그것은 "이 앱은 문장 뜻을
    /// 안 준다"와 구별되지 않았다.
    ///
    /// 세션 설정은 **한 번만** 만든다. 앞으로 돌아올 때마다 새로 만들면 `.translationTask`
    /// 가 그때마다 세션을 다시 열고, 줄도 그때마다 새로 난다.
    private func checkTranslation() async {
        let korean = Locale.Language(identifier: "ko")
        let availability = LanguageAvailability()
        for (identifier, current, keep) in
                [("ja", fromJapanese, { fromJapanese = $0 }),
                 ("en", fromEnglish, { fromEnglish = $0 })]
                as [(String, TranslationSession.Configuration?, (TranslationSession.Configuration) -> Void)] {
            let language = Locale.Language(identifier: identifier)
            let status = await availability.status(from: language, to: korean)
            if identifier == "ja" {
                desk.japanesePack = switch status {
                case .installed: .ready
                case .supported: .needsDownload
                case .unsupported: .unsupported
                @unknown default: .unknown
                }
            }
            // 못 하는 기기에서는 설정을 만들지 않는다 — 열어 두고 실패를 삼키면
            // 애플이 대신 시트를 띄운다.
            guard status != .unsupported, current == nil else { continue }
            keep(TranslationSession.Configuration(source: language, target: korean))
        }
    }

    /// 줄에 선 것을 받아 옮겨 준다. 줄이 끝나면(세션이 물러나면) 이 반복도 끝난다.
    private nonisolated static func serve(_ session: TranslationSession, _ store: Translations) async {
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
