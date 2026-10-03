import SwiftUI
import MworagoCore

/// 연습 — 모은 낱말을 **가나만 보고** 떠올려 본다.
///
/// 기획의 목적지는 쉐도잉(소리 내어 따라 하고 얼마나 닮았는지 보기)이고 그것은 v2.0 이다.
/// 지금 가진 재료로 할 수 있는 것은 **모은 것을 다시 만나는 일**이다 —
/// 가나를 먼저 보이고, 떠올린 다음 뒤집어 확인한다.
///
/// **한글 음차를 앞에 두지 않는다.** 그것은 찾을 때 쓰는 열쇠이지 익힐 것이 아니다.
/// 앞에 두면 한글 음차를 보고 뜻을 떠올리는 연습이 되는데, 목적지는 자막 없이
/// 알아듣는 것이고 자막에 뜨는 것은 가나다. 다만 뒤에는 남긴다 —
/// 어떻게 찾았는지의 기록이자 소리와 글자를 잇는 다리라서, 답의 일부지 문제가 아니다.
///
/// 채점하지 않는다. 맞혔는지 틀렸는지 기록하기 시작하면 점수를 관리하는 앱이 되는데,
/// 여기서 하려는 일은 **다시 마주치게 하는 것**뿐이다.
struct PracticeView: View {
    @Environment(CollectionStore.self) private var collection
    /// 교재에서 하루치만 들고 건너왔을 때 그 낱말들. 비어 있으면 모은 것 전체를 훑는다.
    ///
    /// **늘 전체를 훑으면 오늘 본 것을 다시 만나기까지 한참이 걸린다.** 스무 날치가
    /// 쌓인 뒤에는 더 그렇다. 어느 화를 복습할지는 사용자가 교재에서 고른다.
    var subset: [CollectedWord]? = nil
    var subsetLabel: String? = nil
    /// `--practice-subset=리코리스 리코일 3화` 는 책장에서 그 묶음을 들고 온 것처럼 띄운다.
    /// `--practice-folder=` 와 다르다 — 그쪽은 연습 탭에서 고른 것이라 이름표가 서지 않는다.
    /// 책장을 눌러 건너오는 길은 손으로 두드려야 해서 이 화면을 눈으로 볼 길이 없었다.
    private static var argumentLabel: String? { LaunchOptions.current.value(for: "practice-subset") }
    /// 하루치에서 빠져나와 전체로 돌아간다.
    var onClearSubset: () -> Void = {}

    /// 지금 보고 있는 낱말. **`id` 로 들고 있다** — 자리(번호)로 들면 하루치를 바꾸거나
    /// 낱말을 뺐을 때 같은 번호가 딴 낱말을 가리킨다.
    @State private var currentID: CollectedWord.ID?
    /// 어느 묶음을 연습하는가. `nil` 이면 모은 것 전체다.
    ///
    /// **전체만 훑으면 스무 날치가 쌓인 뒤에 오늘 것을 다시 만나기 어렵다.** 책장에서
    /// 묶음을 열고 연습으로 건너오는 길이 이미 있었는데(`subset`), 그 길은 책장을
    /// 거쳐야 한다 — 연습 탭에 그대로 앉아서도 고를 수 있어야 한다.
    ///
    /// `--practice-folder=리코리스 리코일 3화` 로 그 묶음을 고른 채 띄운다.
    /// `--query=` · `--folder=` 와 같은 취지 — 시뮬레이터는 손으로 두드릴 수 없다.
    @State private var scope: FolderRoute? = LaunchOptions.current
        .value(for: "practice-folder").map { FolderRoute(name: $0.isEmpty ? nil : $0) }
    /// 무엇을 연습할지 고르는 판이 떠 있는가.
    @State private var picking = LaunchOptions.current.has("practice-picking")
    /// `--revealed` 로 뒤집힌 채 띄운다. `--query=` · `--detail` 과 같은 취지 —
    /// 시뮬레이터는 손으로 두드릴 수 없어 뒷면을 눈으로 볼 길이 없다.
    @State private var revealed = LaunchOptions.current.has("revealed")

    /// 들고 온 묶음의 이름. 실행 인자로 띄운 것도 같은 자리에 선다.
    private var label: String? { subsetLabel ?? Self.argumentLabel }

    private var words: [CollectedWord] {
        if let subset { return subset }
        if let name = Self.argumentLabel {
            return collection.words.filter { $0.folder == name }
        }
        guard let scope else { return collection.words }
        return collection.words.filter { $0.folder == scope.name }
    }

    /// 고를 수 있는 묶음들. **비어 있는 것은 넣지 않는다** — 골라 봐야 카드가 없는
    /// 화면으로 가는데, 그 화면에는 다시 고를 단추가 없다.
    /// 차례는 책장과 같다(만들어 둔 순서, 아직 안 넣은 것이 마지막).
    private var pickableFolders: [(route: FolderRoute, count: Int)] {
        var result = collection.folderNames.map { name in
            (FolderRoute(name: name), collection.words.filter { $0.folder == name }.count)
        }
        let loose = collection.words.filter { $0.folder == nil }.count
        if loose > 0 { result.append((FolderRoute(name: nil), loose)) }
        return result.filter { $0.1 > 0 }
    }

    /// 고를 것이 있는가. 묶음이 하나뿐이면 고르는 일이 아니라 전체와 같은 말이다.
    private var canPick: Bool { pickableFolders.count > 1 }
    /// 몇 번째 장인가. 보고 있던 낱말이 사라졌으면 첫 장으로 친다.
    private var index: Int { words.pageIndex(currentID) ?? 0 }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if words.isEmpty {
                PracticeEmptyState()
            } else {
                // **미는 것은 카드뿐이다.**
                //
                // 한때는 머리줄과 단추까지 한 장에 담아 통째로 밀었다. 그런데 저 둘은
                // 장에 딸린 것이 아니라 **화면에 딸린 것**이다 — 스무 장을 넘겨도 `뒤집기`
                // 는 같은 자리에 있어야 손이 그 자리를 기억한다. 머리줄도 장마다 같은
                // 말("연습")을 다시 적으므로, 밀 때마다 같은 글자가 옆에서 흘러들어와
                // 넘어간 것이 아니라 화면이 흔들린 것처럼 보였다.
                VStack(spacing: 0) {
                    header
                    // **카드와 단추가 한 덩어리로 가운데 선다.**
                    //
                    // 한때는 카드 자리가 남은 높이를 통째로 먹었다. 카드는 그 안에서
                    // 가운데 서고 단추는 화면 바닥에 붙으니, 아이패드에서 둘 사이가
                    // 500pt 넘게 벌어졌다 — 뒤집을 것과 뒤집는 단추가 서로 남남으로 보인다.
                    // 눈이 카드에서 단추로 가는 길이 화면 절반이었다.
                    //
                    // 카드가 설 자리를 정해 주고, 남는 높이는 위아래 빈자리가 나눠 갖는다.
                    Spacer(minLength: 0)
                    Pager(items: words, current: $currentID) { word in
                        PracticeCard(word: word, revealed: revealed)
                            // 정해 준 자리 안에서 카드가 가운데 선다.
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: cardArea)
                    buttons
                    Spacer(minLength: 0)
                }
                .padding(.top, Theme.screenTop)
                .padding(.bottom, Theme.screenBottom)
            }
        }
        // 첫 장. 담긴 것이 없다가 생겼을 때도 여기서 잡힌다.
        //
        // **"없으면 첫 낱말" 로 묻지 않는다.** 그렇게 물으면 목록이
        // 비지 않는 한 `nil` 이 아니고, 그러면 `currentID` 는 영영 비어 있게 된다 —
        // 화면은 첫 장을 보여 주는데 넘긴 자리를 아무도 들고 있지 않은 꼴이다.
        .onAppear {
            if words.first(where: { $0.id == currentID }) == nil {
                currentID = words.first?.id
            }
        }
        // 하루치를 새로 골라 오면 처음 낱말부터 시작한다.
        .onChange(of: subsetLabel) { _, _ in
            currentID = words.first?.id
            revealed = false
        }
        // **장이 바뀌면 도로 덮인다.** 밀어서 넘겼든 단추로 넘겼든 같다 —
        // 다음 낱말의 답이 이미 펼쳐져 있으면 떠올려 볼 틈이 없다.
        //
        // **첫 장을 잡을 때는 덮지 않는다.** 화면이 서면서 `currentID` 가 `nil` 에서
        // 첫 낱말로 한 번 바뀌는데, 그것까지 "장이 바뀐 것"으로 세면 `--revealed` 로
        // 펼친 채 띄우는 길이 막힌다(글자 익히기는 이미 막아 둔 자리다).
        .onChange(of: currentID) { 앞, _ in if 앞 != nil { revealed = false } }
        // 묶음을 바꾸면 그 묶음의 첫 장부터 시작한다. 하루치를 새로 골라 올 때와 같다.
        .onChange(of: scope) { _, _ in
            currentID = words.first?.id
            revealed = false
        }
        // **비면 손을 뗀다.** 고른 묶음의 낱말을 다 빼거나 옮기면 카드가 한 장도 없는
        // 화면이 되는데, 그 화면에는 다시 고를 단추가 없다(단추는 머리줄 안에 있다).
        // 책장이 지우던 손을 비는 순간에 푸는 것과 같은 규칙이다.
        .onChange(of: words.isEmpty) { _, empty in
            if empty, scope != nil { scope = nil }
        }
        .dialog(isPresented: $picking) {
            PracticeScopeDialog(folders: pickableFolders,
                                total: collection.words.count,
                                current: scope,
                                isPresented: $picking) { picked in
                // 책장에서 들고 온 하루치가 있으면 놓는다 — 고른 묶음과 겹쳐 두면
                // 화면에 "무엇을 연습 중인가"가 둘이 된다.
                onClearSubset()
                scope = picked
            }
        }
    }

    /// 지금 어디쯤인가. **장을 따라 밀리지 않는다** — 장마다 같은 말을 다시 적는 줄이라,
    /// 밀 때 같은 글자가 옆에서 흘러들어오면 넘어간 것이 아니라 화면이 흔들려 보인다.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("연습")
                .font(Theme.korean(.heading, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("\(min(index + 1, words.count)) / \(words.count)")
                .font(Theme.korean(.body))
                .foregroundStyle(Theme.grey2)
                .monospacedDigit()
            Spacer(minLength: 8)
            // 들고 온 묶음이 있으면 그 이름표가 이 자리에 선다. 그때 고르는 단추는 서지
            // 않는다 — 이름표의 `전체` 가 빠져나오는 길이고, 둘이 나란히 서면 지금 무엇을
            // 보는지 말하는 자리가 둘이 된다.
            if let label {
                PracticeSubsetBanner(label: label, count: words.count, onClear: onClearSubset)
            } else if subset == nil, canPick {
                PracticeScopeButton(title: scope?.title ?? "전체") { picking = true }
            }
        }
        .column()
        .padding(.horizontal, Theme.gutter)
    }

    /// 카드가 설 자리의 높이.
    ///
    /// **높이를 정해 주는 것은 넘길 때 단추가 안 움직이게 하기 위해서다.** 장들은
    /// 필요할 때 만들어지는데(`LazyHStack`), 자리를 카드 크기에 맡기면 뜻이 긴 장이
    /// 들어오는 순간 자리가 늘고 아래 단추가 밀린다. 스무 장을 넘겨도 `뒤집기` 는
    /// 같은 자리에 있어야 손이 그 자리를 기억한다.
    ///
    /// 글자 크기를 키우면 함께 자란다 — 값을 고정하면 키운 사람에게만 카드가 잘린다.
    @ScaledMetric private var cardArea: CGFloat = 300

    /// 누르는 것들. 읽는 덩어리와 달리 **줄째 가운데** 선다.
    private var buttons: some View {
        // 되돌아갈 길이 있어야 한다. 한 장 지나쳐 버렸을 때 스무 장을 다시
        // 넘겨 돌아오게 두지 않는다 — 온보딩의 `이전` 과 같은 이유다.
        // 뒤집을 때마다 `다음` 이 검어지면 셋 중 무엇이 지금 할 일인지가 흐려지고,
        // 화면이 "다음으로 가라"고 재촉하는 것처럼 읽힌다.
        FlipControls(revealed: $revealed, onPrevious: previous, onNext: next)
            .frame(maxWidth: .infinity)
            // 뒤집는 것이 이 화면에서 하는 일이다. 카드가 넘어가는 결로 한 번 알린다 —
            // 답을 맞혔는지 틀렸는지를 말하지 않으므로 성공·실패의 결은 쓰지 않는다.
            .sensoryFeedback(.selection, trigger: revealed)
            .padding(.top, 26)
    }

    /// 한 장 앞으로. 끝에서 누르면 처음으로 돈다.
    private func next() { go(by: 1) }

    /// 한 장 뒤로. 첫 장에서 누르면 마지막 장으로 돌아간다 — `다음` 이 끝에서
    /// 처음으로 도는 것과 짝을 맞춘다.
    private func previous() { go(by: -1) }

    /// 단추로 넘길 때. 미는 손과 같은 자리로 가야 하므로 **보고 있는 낱말을 바꾸고**,
    /// 페이지는 그것을 따라 미끄러진다. 뒤집힌 것을 도로 덮는 일은 `currentID` 가
    /// 바뀔 때 한꺼번에 한다 — 밀어서 넘겼을 때와 같은 자리에서 처리해야 어긋나지 않는다.
    private func go(by offset: Int) {
        guard let id = words.pageID(from: currentID, by: offset) else { return }
        withAnimation(.select) { currentID = id }
    }
}
