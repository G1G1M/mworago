import SwiftUI
@preconcurrency import Translation
import MworagoCore

/// 입력 바가 실제로 놓인 자리.
///
/// **스플래시가 이것을 받아 마지막 알약을 앉힌다.** 전에는 스플래시가 제 숫자를 들고
/// 있었다 — 높이 52, 아래 여백 70. 둘 다 시뮬레이터 하나에서 눈으로 잰 값이라,
/// 폰트가 조금 다르게 그려지거나 탭바 높이가 다른 기기·방향으로 가면 마지막 한 프레임에서
/// 툭 튄다. 그 한 프레임이 "이것이 저것이 되었다"는 말을 통째로 무너뜨린다.
///
/// 재는 대신 **묻는다.** 진짜 입력 바만이 제 자리를 안다.
struct InputBarFrame: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

struct SearchView: View {
    /// 한 줄이 지나치게 길어지면 눈이 되돌아올 곳을 잃는다. iPad 에서 특히 그렇다.
    private static let contentWidth: CGFloat = Theme.listWidth

    /// 담아 두는 곳. 카드의 갈피표가 이것을 쓴다.
    var collection: CollectionStore? = nil
    /// 다른 탭에서 넘어온 검색어. 모은 것이나 도감에서 낱말을 누르면 여기로 들어온다.
    /// 받아서 처리한 뒤 비운다 — 남겨 두면 이 탭으로 돌아올 때마다 다시 검색된다.
    var incoming: Binding<String?>? = nil
    @State private var engine = SearchEngine()
    /// 옮긴 말을 모아 두는 곳. 화면 여럿이 같은 것을 본다.
    @State private var desk = TranslationDesk()
    /// 번역기 설정. **한 번만 만든다** — 문장마다 새로 만들면 그때마다 세션이 다시 열려
    /// 실기기에서 눈에 띄게 걸린다. 세션 여는 일이 번역보다 무겁다.
    @State private var fromJapanese: TranslationSession.Configuration?
    @State private var fromEnglish: TranslationSession.Configuration?
    /// 실행 인자로 검색어를 넣을 수 있다 (`--query=다이죠부`).
    /// 시뮬레이터에 한글을 타이핑하지 않고도 화면을 확인할 수 있어 스크린샷과 점검에 쓴다.
    @State private var input = ProcessInfo.processInfo.arguments
        .first { $0.hasPrefix("--query=") }
        .map { String($0.dropFirst("--query=".count)) } ?? ""
    /// 문장에서 고른 조각. 아무것도 안 골랐을 때가 기본이고, 그때는 카드가 전부 보인다.
    ///
    /// `--select=1` 로 고른 상태를 띄울 수 있다. `--query=` 와 같은 뜻으로, 시뮬레이터를
    /// 손으로 두드리지 않고 화면을 확인하기 위한 것이다.
    @State private var selected: Int? = ProcessInfo.processInfo.arguments
        .first { $0.hasPrefix("--select=") }
        .flatMap { Int($0.dropFirst("--select=".count)) }
    @FocusState private var inputFocused: Bool
    /// 치는 법을 펼쳐 놓았는가. 기본은 접힌 채다.
    ///
    /// `--guide` 로 열린 채 띄울 수 있다. `--query=` · `--select=` 와 같은 뜻으로,
    /// 시뮬레이터를 손으로 두드리지 않고 화면을 확인하기 위한 것이다.
    @State private var showingGuide = ProcessInfo.processInfo.arguments.contains("--guide")
    /// 지금 담으려는 낱말. 있으면 담기 모달이 떠 있다.
    ///
    /// **화면에 하나뿐이어야 한다.** 카드마다 시트를 달면 조각 수만큼 생기고,
    /// 그중 어느 것이 떠 있는지 화면이 스스로 알 수 없게 된다.
    @State private var collecting: CollectedWord?

    var body: some View {
        ZStack {
            // **빈 곳을 누르면 키보드를 내린다.**
            //
            // 키보드가 답의 절반을 덮은 채 남아 있으면 내릴 길이 있어야 한다.
            // 한때 스크롤에도 딸려 내려가게 두었는데(`scrollDismissesKeyboard`),
            // 그쪽은 훑는 손을 걸리게 해서 닫았다. **누르는 길만 연다.**
            //
            // **바탕에만 붙인다.** 화면 전체에 붙이면 카드의 갈피표·소리 단추가 눌리는
            // 자리까지 함께 먹는다. 바탕은 카드가 없는 곳이므로 겹칠 것이 없다.
            Theme.paper
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { inputFocused = false }

            // **글자체를 미리 데운다.** 빈 화면에는 한국어만 있고 일본어는 첫 글자를
            // 칠 때에야 처음 그려진다. 일본어 글자체는 글리프가 많아 파일을 읽는 그 한 번이
            // 눈에 띈다 — 첫 글자에서만 걸리던 것의 한 몫이다.
            // 보이지 않게 한 번 그려 두면 그 읽기가 손 얹히기 전에 끝난다.
            Text("あ")
                .font(Theme.japanese(17))
                .opacity(0)
                .accessibilityHidden(true)

            // **입력 바는 화면에 하나뿐이고, 늘 이 자리(둘째)에 선다.**
            //
            // 한때 답이 있을 때와 없을 때 서로 다른 자리에서 따로 만들었다. 그러면
            // 첫 글자를 치는 순간 `TextField` 가 헐리고 다시 세워지면서 `@FocusState` 가
            // 풀린다 — 키보드가 내려가고 **한 글자만 치면 입력이 끊겼다.**
            //
            // 그래서 자식 셋의 차례를 고정한다. 위(글 또는 목록) · 바 · 아래 빈자리.
            // 답이 없을 때만 위아래 빈자리가 벌어져 바가 글에 붙은 채 가운데로 온다.
            VStack(spacing: 0) {
                // **바는 처음부터 바닥에 선다.**
                //
                // 한때는 답이 없을 때 글과 바를 화면 한가운데 모아 두었다가, 손이 얹히면
                // 바닥으로 내려보냈다. 읽은 자리에서 바로 손이 가게 하려던 것인데,
                // 자리를 옮기는 그 순간이 **첫 글자를 치는 순간과 겹쳤다** —
                // 바가 움직이고 화면이 다시 서는 일이 첫 검색과 한꺼번에 몰렸다.
                //
                // 바가 처음부터 자기 자리에 있으면 그 겹침이 아예 없다. 누를 때 키보드만
                // 올라오고, 칠 때는 찾는 일만 남는다. 글은 바 바로 위에 붙어 함께 내려와
                // 있으므로, 읽은 자리에서 손이 가는 것도 그대로다.
                Spacer(minLength: 0)
                // **키보드가 올라와도 목록은 제자리에 둔다.**
                //
                // 키보드가 올라오면 안전 영역이 줄어 위쪽까지 함께 밀려 올라간다.
                // 손이 얹히는 순간 답이 통째로 들썩이는데, 읽던 자리를 눈이 다시 찾아야 한다.
                // 목록은 키보드를 못 본 척하고, **바만 그 위로 올라간다.**
                content
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                inputBar
            }
        }
        .environment(desk)
        // **세션은 언어쌍마다 하나씩, 앱이 사는 동안 그대로 둔다.** 열어 놓고 옮길 것을
        // 흘려 넣는다. 번역을 못 하는 기기에서는 설정을 만들지 않으므로 세션도 열리지
        // 않는다 — 열어 두고 실패를 삼키면 애플이 대신 시트를 띄운다.
        .task {
            // 색인·규칙표·캐시를 손 얹히기 전에 한 번 지나가게 한다.
            engine.prewarm()
            let korean = Locale.Language(identifier: "ko")
            let availability = LanguageAvailability()
            for (identifier, keep) in [("ja", { fromJapanese = $0 }), ("en", { fromEnglish = $0 })]
                    as [(String, (TranslationSession.Configuration) -> Void)] {
                let language = Locale.Language(identifier: identifier)
                guard await availability.status(from: language, to: korean) != .unsupported else { continue }
                keep(TranslationSession.Configuration(source: language, target: korean))
            }
        }
        .translationTask(fromJapanese) { session in
            await Self.serve(session, desk.japanese)
        }
        .translationTask(fromEnglish) { session in
            await Self.serve(session, desk.english)
        }
        .onChange(of: incoming?.wrappedValue) { _, new in
            guard let new, !new.isEmpty else { return }
            input = new
            engine.search(new)
            selected = nil
            incoming?.wrappedValue = nil
        }
        .onAppear {
            // `--collect` 는 검색 결과를 전부 담는다. 담기와 모은 것 화면을
            // 손으로 두드리지 않고 확인하기 위한 것이다.
            if ProcessInfo.processInfo.arguments.contains("--collect"), let collection {
                engine.searchNow(input)
                for segment in engine.segments {
                    guard let top = segment.results.first else { continue }
                    collection.add(CollectedWord(headword: top.headword,
                                                 reading: top.reading,
                                                 hangul: segment.hangul,
                                                 gloss: top.entry.displayGloss,
                                           partOfSpeech: top.entry.wordClass.displayName),
                                   to: nil)
                }
            }
            // **스스로 키보드를 올리지 않는다.**
            //
            // 처음 열면 바로 칠 수 있게 하려던 것이었는데, `onAppear` 는 스플래시와
            // 온보딩이 위에 덮여 있어도 돈다 — 실기기에서 앱을 열면 온보딩 뒤에서
            // 키보드가 먼저 올라왔다. 탭을 오갈 때마다 다시 올라오기도 한다.
            //
            // 키보드는 **칠 때** 올라오면 된다. 입력 바를 누르는 것이 그 신호다.
            if !input.isEmpty { engine.search(input) }

            // `--collecting` 은 첫 조각의 담기 모달을 펼친 채 띄운다. `--detail` · `--guide` 와
            // 같은 취지다 — 시뮬레이터는 손으로 두드릴 수 없어 시트를 눈으로 볼 길이 없다.
            if ProcessInfo.processInfo.arguments.contains("--collecting"),
               let top = engine.segments.first?.results.first,
               let hangul = engine.segments.first?.hangul {
                collecting = CollectedWord(headword: top.headword,
                                           reading: top.reading,
                                           hangul: hangul,
                                           gloss: top.entry.displayGloss)
            }
        }
        .sheet(isPresented: $showingGuide) {
            // 아이패드에서 medium 은 화면의 작은 조각이라 여섯 줄 중 둘만 보인다.
            TypingGuide()
        }
        // 담기 모달. **화면에 하나만 둔다** — 갈피표는 카드마다 있지만
        // 묻는 자리는 하나여야 한다.
        .sheet(item: $collecting) { word in
            if let collection {
                FolderPicker(word: word,
                             folderNames: collection.folderNames,
                             lastFolder: collection.lastFolder) { folder in
                    collection.add(word, to: folder)
                }
            }
        }
    }

    // MARK: 결과

    /// 돌려줄 답이 있는가.
    private var hasResults: Bool {
        engine.failure == nil && !input.isEmpty && !engine.segments.isEmpty
    }

    /// 입력 바가 바닥에 서는가.
    ///
    /// **손이 얹히는 순간 내려간다.** 답이 있을 때만 내려가게 두었더니, 바를 눌러도
    /// 키보드만 올라오고 바는 가운데 그대로였다 — 치기 시작해서 첫 글자가 답을 낼 때에야
    /// 뒤늦게 내려앉는다. 누른 자리와 글자가 찍히는 자리가 달라지는 셈이다.
    ///
    /// **첫 글자의 부담도 덜어 준다.** 답이 있을 때만 내려가게 두면 첫 글자를 치는 순간
    /// 바가 옮겨 가는 그림과 화면 재배치가 첫 검색과 한꺼번에 일어난다.
    /// 누를 때 자리를 미리 잡아 두면 그 순간에는 찾는 일만 남는다.
    ///

    /// 세션 하나를 붙들고, 줄에 들어오는 것을 옮겨 담는다.
    ///
    /// 줄이 닫히기 전까지 돌아오지 않는다. 그래야 세션이 살아 있고, 다음 문장을 물을 때
    /// 다시 열지 않아도 된다 — 그 다시 열기가 곧 실기기에서 느껴지던 걸림이었다.
    private nonisolated static func serve(_ session: TranslationSession, _ store: Translations) async {
        for await batch in store.requests {
            let asked = batch.map { TranslationSession.Request(sourceText: $0) }
            var responses = try? await session.translations(from: asked)
            if responses == nil {
                // **한 번은 더 물어본다.** 언어팩을 아직 내려받는 중이면 첫 물음이 빈손으로
                // 돌아온다. 그 한 번 때문에 문장이 영영 안 뜨는 것은 사용자가 알 길이 없다.
                try? await Task.sleep(for: .milliseconds(400))
                responses = try? await session.translations(from: asked)
            }
            guard let responses else {
                await MainActor.run { store.forget(batch) }
                continue
            }
            let pairs = responses.map { (source: $0.sourceText, target: $0.targetText) }
            await MainActor.run { store.receive(pairs) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let failure = engine.failure {
            resting { notice("사전을 열지 못했습니다", detail: failure) }
        } else if input.isEmpty {
            resting { emptyState }
        } else if engine.segments.isEmpty {
            resting { notice("찾지 못했습니다", detail: "다르게 들렸을 수도 있어요. 한 글자만 바꿔 보세요.") }
        } else {
            results
        }
    }

    /// 아직 답이 없을 때 놓이는 자리 — 위쪽 빈자리가 글을 아래로 민다.
    ///
    /// 바를 화면 바닥에 두면 "들린 대로 치세요"와 실제로 치는 자리가 화면 절반만큼
    /// 떨어진다. 읽은 자리에서 바로 손이 가야 하므로 글이 바까지 내려와 붙는다.
    /// 바 자체는 `body` 가 들고 있다 — 여기서 만들면 답이 나올 때 헐렸다 다시 서고,
    /// 그 순간 키보드가 내려간다.
    private func resting<V: View>(@ViewBuilder _ inner: () -> V) -> some View {
        inner()
            .frame(maxWidth: Self.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { inputFocused = false }
    }

    private var results: some View {
        ScrollViewReader { scroller in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // 되살린 원문이 맨 위에 온다. 문장을 치고 들어왔으니 문장부터 돌려준다.
                    //
                    // 조각이 하나뿐이면 내보내지 않는다. 그때는 문장이 곧 낱말이라
                    // 바로 아래 카드와 같은 말을 두 번 하게 된다 (아타마가이타이 → 頭が痛い 는
                    // 사전에 통째로 실려 있어 한 조각으로 나온다).
                    if engine.segments.count > 1 {
                        // 문장 뜻은 헤더 **안**에 셋째 층으로 들어 있다. 되살린 문장과
                        // 그것을 옮긴 말은 한 덩어리라, 사이에 덩어리를 닫는 여백이
                        // 끼면 안 된다.
                        SentenceHeader(segments: engine.segments, selected: $selected)
                        Divider().overlay(Theme.grey3).padding(.horizontal, Theme.gutter)
                    }

                    ForEach(Array(engine.segments.enumerated()), id: \.offset) { index, segment in
                        SegmentCard(segment: segment,
                                    isSelected: selected == index, collection: collection,
                                    onCollect: { collecting = $0 })
                            .id(index)
                        Divider().overlay(Theme.grey3).padding(.horizontal, Theme.gutter)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
                .frame(maxWidth: Self.contentWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                // **여기에도 붙여야 닿는다.** 바탕에만 두었더니 목록이 있을 때는
                // 손가락이 바탕까지 가지 못했다 — 스크롤 뷰가 자기 자리의 탭을 먼저 먹는다.
                // 카드 안의 갈피표·소리 단추는 자식이라 먼저 처리되므로 가려지지 않는다.
                .contentShape(Rectangle())
                .onTapGesture { inputFocused = false }
            }
            // **스크롤로는 내리지 않는다.**
            //
            // `.interactively` 는 손가락을 따라 키보드를 조금씩 밀어 내린다. 그 사이
            // 화면이 매 프레임 다시 서는데, 목록이 길수록 그 값이 커져 훑는 손이 걸린다.
            // 내리는 길은 바탕을 누르는 쪽으로 이미 나 있으므로 여기서는 닫아 둔다 —
            // 답을 훑는 일이 키보드를 내리는 일보다 자주 있다.
            .scrollDismissesKeyboard(.never)
            // 문장에서 조각을 누르면 그 낱말로 데려간다. 긴 문장에서 카드가 화면 밖에 있으면
            // 눌러도 아무 일이 없어 보이기 때문이다.
            .onChange(of: selected) { _, new in
                guard let new else { return }
                withAnimation(.snappy(duration: 0.25)) { scroller.scrollTo(new, anchor: .top) }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("들린 대로 치세요")
                .font(Theme.korean(26, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("띄어 쓰지 않아도 됩니다. 어디서 끊을지는 사전이 정해요.")
                .font(Theme.korean(15))
                .foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 24)
    }

    private func notice(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.korean(19, weight: .medium)).foregroundStyle(Theme.ink)
            Text(detail).font(Theme.korean(14)).foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 24)
    }

    // MARK: 입력 바 — 떠 있는 컨트롤에만 유리를 쓴다

    private var inputBar: some View {
        VStack(spacing: 10) {

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.grey2)
                TextField("콘니치와", text: $input)
                    .font(Theme.korean(19))
                    .foregroundStyle(Theme.ink)
                    .focused($inputFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: input) { _, new in
                        // 조각이 다시 나뉘므로 번호로 잡아 둔 선택은 뜻을 잃는다.
                        selected = nil
                        engine.search(new)
                    }
                if !input.isEmpty {
                    Button {
                        input = ""
                        engine.search("")
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.grey3)
                    }
                    .buttonStyle(.plain)
                }
                // 입력에 대한 도움말이라 입력 곁에 둔다. 표준 기호를 그대로 쓰고 색만 맞춘다.
                Button { showingGuide = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(Theme.grey2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("한글로 치는 법")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.grey3.opacity(0.5), lineWidth: 0.5)
            )
            // 스플래시가 마지막에 여기로 와서 앉는다. 화면 좌표로 올려야
            // 스플래시가 제 좌표계로 옮겨 쓸 수 있다.
            .background {
                GeometryReader { bar in
                    Color.clear.preference(key: InputBarFrame.self,
                                           value: bar.frame(in: .global))
                }
            }
        }
        .frame(maxWidth: Self.contentWidth)
        // 떠 있는 바지만 가장자리는 글이 시작하는 자리에 맞춘다 — 혼자 4pt 밖으로
        // 나가 있으면 아래로 스크롤할 때 바깥선이 본문과 어긋나 보인다.
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 14)
    }
}
