import SwiftUI
import MworagoCore

struct SearchView: View {
    /// 한 줄이 지나치게 길어지면 눈이 되돌아올 곳을 잃는다. iPad 에서 특히 그렇다.
    private static let contentWidth: CGFloat = Theme.listWidth

    /// 다른 탭에서 넘어온 검색어. 모은 것이나 도감에서 낱말을 누르면 여기로 들어온다.
    /// 받아서 처리한 뒤 비운다 — 남겨 두면 이 탭으로 돌아올 때마다 다시 검색된다.
    var incoming: Binding<String?>? = nil
    /// 담은 자리로 건너가는 길. 알림 줄을 누르면 책장의 그 묶음이 열린다.
    var onOpenFolder: (FolderRoute) -> Void = { _ in }

    /// 담아 두는 곳. 카드의 갈피표가 이것을 쓴다.
    @Environment(CollectionStore.self) private var collection
    /// 사전을 열고 검색을 맡는다. **조립 루트가 세운다** — 예전에는 이 화면이
    /// 직접 만들었고, 그래서 사전을 여는 일이 찾기 탭이 처음 그려질 때 일어났다.
    @Environment(SearchEngine.self) private var engine
    /// 실행 인자로 검색어를 넣을 수 있다 (`--query=다이죠부`).
    /// 시뮬레이터에 한글을 타이핑하지 않고도 화면을 확인할 수 있어 스크린샷과 점검에 쓴다.
    @State private var input = LaunchOptions.current.value(for: "query") ?? ""
    /// 문장에서 고른 조각. 아무것도 안 골랐을 때가 기본이고, 그때는 카드가 전부 보인다.
    ///
    /// `--select=1` 로 고른 상태를 띄울 수 있다. `--query=` 와 같은 뜻으로, 시뮬레이터를
    /// 손으로 두드리지 않고 화면을 확인하기 위한 것이다.
    @State private var selected: Int? = LaunchOptions.current.int(for: "select")
    @FocusState private var inputFocused: Bool
    /// 치는 법을 펼쳐 놓았는가. 기본은 접힌 채다.
    ///
    /// `--guide` 로 열린 채 띄울 수 있다. `--query=` · `--select=` 와 같은 뜻으로,
    /// 시뮬레이터를 손으로 두드리지 않고 화면을 확인하기 위한 것이다.
    @State private var showingGuide = LaunchOptions.current.has("guide")
    /// 지금 담으려는 낱말. 있으면 담기 모달이 떠 있다.
    ///
    /// **화면에 하나뿐이어야 한다.** 카드마다 시트를 달면 조각 수만큼 생기고,
    /// 그중 어느 것이 떠 있는지 화면이 스스로 알 수 없게 된다.
    @State private var collecting: CollectedWord?
    /// 바닥에 뜬 것들(담은 자리 줄 · 입력 바)의 높이. 답 목록이 이만큼 그 밑으로 흘러든다.
    @State private var dockHeight: CGFloat = 0

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
                .font(Theme.japanese(.title))
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
                // **빈자리 둘이 형제로 나란히 있어야 반반 나눠 갖는다.** 그래야 글과 바가
                // 한 덩어리로 화면 한가운데 선다.
                //
                // 한때 바를 처음부터 바닥에 세우고 키보드가 설 자리를 미리 비워 두었다.
                // 자리를 옮기지 않으려던 것인데, **키보드 높이는 기기마다 다르다** —
                // 재어 기억해도 다른 기기·다른 글자판에서는 어긋난 자리에 굳는다.
                // 비워 둘 수 없는 높이라면 비우지 않는 편이 낫다.
                Spacer(minLength: 0)
                    .frame(maxHeight: hasResults ? 0 : .infinity)
                // 답은 키보드를 못 본 척한다 — 손이 얹힐 때마다 목록이 들썩이면
                // 읽던 자리를 눈이 다시 찾아야 한다.
                content
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    // **답은 입력 바 밑까지 내려간다.** 바가 유리인데 목록이 바 윗선에서
                    // 끝나면, 유리 뒤에는 늘 빈 종이뿐이라 막힌 판으로 보였다. 탭바처럼
                    // 글이 밑으로 지나가야 유리가 유리로 읽힌다. 바는 뒤에 적혀 위에 그려진다.
                    .padding(.bottom, hasResults ? -dockHeight : 0)
                // 바닥에 뜬 것들을 한 덩어리로 잰다. 이 묶음은 답이 있든 없든 늘 여기 서므로
                // 입력 바의 자리(둘째)도 바뀌지 않는다.
                VStack(spacing: 0) {
                    if let saved = justSaved {
                        SavedNotice(saved: saved,
                                    onOpen: {
                                        justSaved = nil
                                        onOpenFolder(saved)
                                    },
                                    onExpire: {
                                        withAnimation(.easeOut(duration: 0.2)) { justSaved = nil }
                                    })
                            .padding(.bottom, 8)
                            .transition(.opacity)
                    }
                    SearchInputBar(text: $input,
                                   focused: $inputFocused,
                                   onClear: {
                                       input = ""
                                       engine.search("")
                                   },
                                   onGuide: { showingGuide = true })
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { dockHeight = $0 }
                // 아래쪽은 **손이 얹히는 순간에도** 닫는다. 그래야 바가 바닥까지 내려가
                // 키보드가 그 자리에서 곧바로 밀어 올린다 — 키보드 바로 위가 바의 자리다.
                Spacer(minLength: 0)
                    .frame(maxHeight: hasResults || inputFocused ? 0 : .infinity)
            }
            // **두 움직임이 겹쳐 한 번으로 보이게 한다.**
            //
            // 빈자리가 닫히는 것과 키보드가 밀어 올리는 것은 서로 다른 일이라, 그냥 두면
            // 바가 바닥까지 **내려갔다가 다시 올라온다.** 두 걸음이 눈에 보인다.
            //
            // 빈자리 닫힘을 키보드와 같은 길이·같은 결로 움직이면 둘이 포개져,
            // 바가 가운데에서 키보드 위로 **곧장 내려앉는 한 걸음**이 된다.
            // 0.25초와 easeOut 은 시스템 키보드가 쓰는 값이다.
            .animation(.easeOut(duration: 0.25), value: inputFocused)
        }
        // **번역 세션은 여기 없다.** `RootView` 가 연다 — 까닭은 그쪽에 적어 두었다.
        // 요약하면 이렇다: `.translationTask` 는 뷰가 물러나면 취소되는데, 탭을 다녀와도
        // 설정 값이 그대로라 다시 돌지 않는다. 찾기 탭에 매어 두면 탭을 한 번 다녀온
        // 뒤로 어떤 문장도 옮겨지지 않았다.
        .task {
            // 색인·규칙표·캐시를 손 얹히기 전에 한 번 지나가게 한다.
            engine.prewarm()
        }
        .onChange(of: input) { _, new in
            // 조각이 다시 나뉘므로 번호로 잡아 둔 선택은 뜻을 잃는다.
            selected = nil
            engine.search(new)
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
            if LaunchOptions.current.has("collect") {
                engine.searchNow(input)
                for segment in engine.segments {
                    guard let top = segment.results.first else { continue }
                    collection.add(CollectedWord(result: top, hangul: segment.hangul,
                                                 gloss: top.entry.displayGloss),
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

            // `--collecting` 은 첫 조각의 담기 판을 펼친 채 띄운다. `--detail` · `--guide` 와
            // 같은 취지다 — 시뮬레이터는 손으로 두드릴 수 없어 이 판을 눈으로 볼 길이 없다.
            //
            // **먼저 찾아 놓고 본다.** 위의 `search` 는 손이 멎기를 기다렸다 도는 것이라
            // 이 자리에서는 아직 답이 없다 — `--collect` 가 `searchNow` 를 쓰는 것과 같다.
            if LaunchOptions.current.has("collecting") {
                engine.searchNow(input)
            }
            if LaunchOptions.current.has("collecting"),
               let top = engine.segments.first?.results.first,
               let hangul = engine.segments.first?.hangul {
                collecting = CollectedWord(result: top, hangul: hangul, gloss: top.entry.displayGloss)
            }
        }
        .sheet(isPresented: $showingGuide) {
            // 아이패드에서 medium 은 화면의 작은 조각이라 여섯 줄 중 둘만 보인다.
            TypingGuide()
        }
        // 담기 판. **화면에 하나만 둔다** — 갈피표는 카드마다 있지만
        // 묻는 자리는 하나여야 한다.
        .dialog(item: $collecting) { word in
            FolderPicker(word: word,
                         folderNames: collection.folderNames,
                         lastFolder: collection.lastFolder,
                         onPick: { folder in
                             collection.add(word, to: folder)
                             justSaved = FolderRoute(name: folder)
                         },
                         onClose: { collecting = nil })
        }
    }

    // MARK: 결과

    /// 방금 담은 곳. **어디로 들어갔는지 화면에 남긴다.**
    ///
    /// 판을 닫고 나면 갈피표가 채워지는 것 말고는 아무 흔적이 없었다. 묶음이 여럿인
    /// 사람은 자기가 무엇을 골랐는지 곧 잊는다 — 고른 것이 판과 함께 사라지기 때문이다.
    /// 잠깐 떠 있다 스스로 물러난다. 무를 수 있는 일이라 확인을 받지 않는다.
    /// 누르면 그 묶음으로 건너간다.
    ///
    /// `--saved=리코리스 리코일 3화` 로 그 줄을 띄운 채 시작한다. `--collecting` 과 같은
    /// 취지인데, 이것은 **띄우는 것만으로는 부족하다** — 1.2초 뒤에 스스로 물러나므로
    /// 시뮬레이터에서 찍으려 들면 매번 다른 것이 찍힌다. 그래서 이 인자로 띄운 줄은
    /// 물러나지 않는다(`SavedNotice` 의 `task`).
    @State private var justSaved: FolderRoute? = SavedNotice.pinned

    /// 돌려줄 답이 있는가.
    private var hasResults: Bool {
        engine.failure == nil && !input.isEmpty && !engine.segments.isEmpty
    }

    /// 답 자리 — 사전을 못 열었거나, 아직 안 쳤거나, 못 찾았거나, 답이 있거나.
    @ViewBuilder
    private var content: some View {
        if let failure = engine.failure {
            resting { SearchNotice(title: "사전을 열지 못했어요", detail: failure) }
        } else if input.isEmpty {
            // **손이 얹히면 안내문은 물러난다.** 읽으라고 둔 글인데, 치기 시작한 사람에게는
            // 이미 읽은 글이다. 키보드가 올라오는 좁은 자리를 그 글이 차지하고 있을 이유가 없다.
            if !inputFocused { resting { SearchPrompt() } }
        } else if engine.segments.isEmpty {
            resting { SearchNotice(title: SearchNotice.notFoundTitle, detail: SearchNotice.notFoundDetail) }
        } else {
            results
        }
    }

    /// 아직 답이 없을 때 놓이는 자리 — 위쪽 빈자리가 글을 아래로 민다.
    ///
    /// 바를 화면 바닥에 두면 "일본어를 들리는 대로 쳐보세요"와 치는 자리가 화면 절반만큼
    /// 떨어진다. 읽은 자리에서 바로 손이 가야 하므로 글이 바까지 내려와 붙는다.
    /// 바 자체는 `body` 가 들고 있다 — 여기서 만들면 답이 나올 때 헐렸다 다시 서고,
    /// 그 순간 키보드가 내려간다.
    private func resting<V: View>(@ViewBuilder _ inner: () -> V) -> some View {
        inner()
            .column(Self.contentWidth)
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
                        SentenceHeader(segments: engine.segments, selected: $selected,
                                       onCollect: { collecting = $0 })
                        Theme.rule().padding(.horizontal, Theme.gutter)
                    }

                    ForEach(Array(engine.segments.enumerated()), id: \.offset) { index, segment in
                        SegmentCard(segment: segment,
                                    isSelected: selected == index,
                                    onCollect: { collecting = $0 })
                            .id(index)
                        Theme.rule().padding(.horizontal, Theme.gutter)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
                .column(Self.contentWidth)
                // **여기에도 붙여야 닿는다.** 바탕에만 두었더니 목록이 있을 때는
                // 손가락이 바탕까지 가지 못했다 — 스크롤 뷰가 자기 자리의 탭을 먼저 먹는다.
                // 카드 안의 갈피표·소리 단추는 자식이라 먼저 처리되므로 가려지지 않는다.
                .contentShape(Rectangle())
                .onTapGesture { inputFocused = false }
            }
            .scrollBounceBehavior(.basedOnSize)
            // 밑으로 흘러든 만큼 끝에 자리를 남긴다 — 마지막 카드도 바 위까지 올려 읽을 수 있게.
            .contentMargins(.bottom, dockHeight)
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
}
