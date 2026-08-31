import SwiftUI
import MworagoCore

/// 무엇까지 보여줄지. 듀오링고가 발음 표시를 끄고 켜게 하듯,
/// 익숙해질수록 아래 층부터 끄는 다이얼이다.
///
/// **가나가 맨 위다.** 소리를 듣고 찾아온 사람에게 가장 가까운 것이 가나이기 때문이다.
/// 한자는 아직 못 읽을 수 있고, 일본어를 배우며 처음 만나는 것도 가나다.
enum ReadingAid: Int, CaseIterable, Identifiable {
    case hangul, kanji, kana

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .hangul: "한글까지"
        case .kanji: "한자까지"
        case .kana: "가나만"
        }
    }
    var showsKanji: Bool { self != .kana }
    var showsHangul: Bool { self == .hangul }

    init?(name: String) {
        switch name {
        case "hangul": self = .hangul
        case "kanji": self = .kanji
        case "kana": self = .kana
        default: return nil
        }
    }
}

struct SearchView: View {
    /// 한 줄이 지나치게 길어지면 눈이 되돌아올 곳을 잃는다. iPad 에서 특히 그렇다.
    private static let contentWidth: CGFloat = Theme.listWidth
    /// 입력 바가 차지하는 높이. 그 위에 다른 것을 놓을 때 겹치지 않게 비워 둘 만큼이다.
    private static let inputBarHeight: CGFloat = 92
    /// 읽기 보조 다이얼까지 얹혔을 때의 높이. 결과가 있을 때만 다이얼이 나오므로
    /// 목록의 아래 여백은 이쪽을 쓴다 — 120 으로 두었다가 다이얼이 카드를 덮었다.
    private static let inputBarWithDialHeight: CGFloat = 152

    /// 담아 두는 곳. 카드의 갈피표가 이것을 쓴다.
    var collection: CollectionStore? = nil
    /// 다른 탭에서 넘어온 검색어. 모은 것이나 도감에서 낱말을 누르면 여기로 들어온다.
    /// 받아서 처리한 뒤 비운다 — 남겨 두면 이 탭으로 돌아올 때마다 다시 검색된다.
    var incoming: Binding<String?>? = nil

    @State private var engine = SearchEngine()
    /// 실행 인자로 검색어를 넣을 수 있다 (`--query=다이죠부`).
    /// 시뮬레이터에 한글을 타이핑하지 않고도 화면을 확인할 수 있어 스크린샷과 점검에 쓴다.
    @State private var input = ProcessInfo.processInfo.arguments
        .first { $0.hasPrefix("--query=") }
        .map { String($0.dropFirst("--query=".count)) } ?? ""
    /// 읽기 보조 다이얼도 실행 인자로 고를 수 있다 (`--aid=kana`).
    /// `--query=` 와 같은 까닭이다 — 시뮬레이터를 손으로 누르지 않고 세 상태를 다 확인하려고.
    @State private var aid: ReadingAid = ProcessInfo.processInfo.arguments
        .first { $0.hasPrefix("--aid=") }
        .flatMap { ReadingAid(name: String($0.dropFirst("--aid=".count))) } ?? .hangul
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
        ZStack(alignment: .bottom) {
            Theme.paper.ignoresSafeArea()

            content
            inputBar
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
                engine.search(input)
                for segment in engine.segments {
                    guard let top = segment.results.first else { continue }
                    collection.add(CollectedWord(headword: top.headword,
                                                 reading: top.reading,
                                                 hangul: segment.hangul,
                                                 gloss: top.entry.displayGloss),
                                   to: nil)
                }
            }
            if input.isEmpty { inputFocused = true } else { engine.search(input) }

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

    /// 아직 답이 없을 때 놓이는 자리 — **입력 바 바로 위**다.
    ///
    /// 위에 붙여 두면 아이패드에서 화면 절반이 통째로 비고, 시선이 맨 위와 맨 아래로 갈라진다.
    /// 손이 있는 곳도 글을 읽을 곳도 아래쪽이므로 한 덩어리로 모으고, 남는 여백은 위에 둔다.
    private func resting<V: View>(@ViewBuilder _ inner: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            inner()
        }
        .frame(maxWidth: Self.contentWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.bottom, Self.inputBarHeight)
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
                        SentenceHeader(segments: engine.segments, aid: aid, selected: $selected)
                        Divider().overlay(Theme.grey3)
                    }

                    ForEach(Array(engine.segments.enumerated()), id: \.offset) { index, segment in
                        SegmentCard(segment: segment, aid: aid, hanja: engine.hanja,
                                    isSelected: selected == index, collection: collection,
                                    onCollect: { collecting = $0 })
                            .id(index)
                        Divider().overlay(Theme.grey3)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, Self.inputBarWithDialHeight)   // 입력 바와 다이얼에 가리지 않도록
                .frame(maxWidth: Self.contentWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
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

            VStack(alignment: .leading, spacing: 10) {
                ForEach(["다이죠부", "아타마가이타이", "이타이야메로"], id: \.self) { example in
                    Button {
                        input = example
                        engine.search(example)
                    } label: {
                        HStack(spacing: 8) {
                            Text(example).font(Theme.korean(16))
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.grey3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Theme.grey4, in: Capsule())
                        .foregroundStyle(Theme.grey1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
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
            if !input.isEmpty { aidDial }

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.grey2)
                TextField("다이죠부", text: $input)
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
        }
        .frame(maxWidth: Self.contentWidth)
        // 떠 있는 바지만 가장자리는 글이 시작하는 자리에 맞춘다 — 혼자 4pt 밖으로
        // 나가 있으면 아래로 스크롤할 때 바깥선이 본문과 어긋나 보인다.
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 14)
    }

    /// 강조는 반전 하나로만 — 고른 것이 검게 채워진다.
    private var aidDial: some View {
        HStack(spacing: 6) {
            ForEach(ReadingAid.allCases) { option in
                let selected = option == aid
                Button {
                    withAnimation(.snappy(duration: 0.18)) { aid = option }
                } label: {
                    Text(option.label)
                        .font(Theme.korean(13, weight: selected ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selected ? Theme.ink : .clear, in: Capsule())
                        .foregroundStyle(selected ? Theme.paper : Theme.grey2)
                }
                .buttonStyle(.plain)
            }
        }
        // **다이얼도 떠 있는 컨트롤이다.** 입력 바만 유리를 두르고 이쪽은 맨몸이라,
        // 뒤로 지나가는 카드 글자가 그대로 비쳐 읽기 어려웠다.
        // 내용만큼만 차지하게 두고 같은 유리를 씌운다.
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.grey3.opacity(0.5), lineWidth: 0.5))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
