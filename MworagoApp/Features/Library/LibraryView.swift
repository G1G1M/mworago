import SwiftUI
import MworagoCore

/// 교재 — 모아 둔 낱말을 **날짜로 묶어** 보거나 **하나씩** 본다.
///
/// 원래 "모은 것"과 "도감"으로 탭이 갈려 있었는데, 둘은 같은 낱말을 평평하게 보느냐
/// 날짜로 묶어 보느냐의 차이뿐이었다. 탭 두 칸을 쓸 만큼 다른 일이 아니고,
/// 담기 전에는 **빈 화면이 둘**이라 처음 온 사람에게 같은 말을 두 번 했다.
///
/// 기획의 "화별 교재"는 앱이 알 수 없다 — 어느 화를 보다 걸렸는지는 사용자만 안다.
/// 그러나 애니 한 화를 보며 찾은 것들은 같은 날 모이므로 **날짜가 사실상 그 화다.**
///
/// **묶음은 한 줄로 서고, 누르면 그 묶음의 화면으로 들어간다.** 한때는 낱말을 그 자리에
/// 다 펼쳤는데, 한 편만 봤을 때는 괜찮아도 다섯 편이 쌓이면 책장이 다섯 배로 길어지고
/// 스무 편이면 훑을 수 없는 화면이 됐다. 대신 줄 오른쪽에 낱말 두어 개를 흘려 두어
/// **이름만으로 "어느 화였지"를 짚지 않아도 되게** 한다.
struct LibraryView: View {
    @Environment(CollectionStore.self) private var collection
    /// 밖에서 열어 달라고 건네는 묶음. 담은 자리를 알리는 줄을 누르면 여기로 온다.
    ///
    /// **받아서 열고 비운다** — 남겨 두면 책장 탭으로 돌아올 때마다 그 묶음이 다시 열린다.
    /// `SearchView.incoming` 과 같은 문법이다.
    var incomingFolder: Binding<FolderRoute?>? = nil
    /// 상세에서 "찾기에서 보기"를 눌렀을 때 건너가는 길.
    ///
    /// 전에는 **낱말을 누르는 것 자체가** 이 길이었다. 모아 둔 것을 다시 만나게 하려던
    /// 것인데, 교재에서 나가 버리니 여러 개를 훑을 때마다 돌아와야 했다.
    /// 이제 누르면 상세가 열리고, 이 길은 그 안의 버튼으로 남는다.
    var onPick: (String) -> Void = { _ in }
    /// 그날 것만 들고 연습으로 건너간다. 연습이 늘 전체를 훑으면
    /// 스무 날치가 쌓인 뒤에는 오늘 본 것을 다시 만나기까지 한참이 걸린다.
    /// 한 묶음을 들고 연습으로 건너간다. 이름표에 적을 이름을 함께 넘긴다.
    var onPractice: ([CollectedWord], String) -> Void = { _, _ in }

    enum Grouping: Int, CaseIterable, Identifiable {
        case folders, days, list
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .folders: "묶음별"
            case .days: "날짜별"
            case .list: "모두"
            }
        }
    }

    /// 어느 묶음으로 들어갔는가.
    ///
    /// 묶음과 날짜가 한 갈래를 쓴다 — 둘 다 "낱말 한 무리"이고 화면도 같다.
    /// 다른 것은 손볼 수 있느냐뿐이다(날짜는 앱이 센 것이라 이름을 고칠 것이 없다).
    private enum Route: Hashable {
        case folder(String?)
        case day(Date)
    }

    @State private var path: [Route] = []
    @State private var grouping: Grouping = .folders
    /// 펼쳐 보고 있는 낱말. 누르면 여기 담기고 상세가 열린다.
    ///
    /// `--detail` 로 첫 낱말을 펼친 채 띄울 수 있다. `--query=` · `--guide` 와 같은
    /// 취지다 — 시뮬레이터는 손으로 두드릴 수 없어 시트를 눈으로 볼 길이 없다.
    @State private var detail: CollectedWord?
    /// 실행 인자로 열라던 것을 이미 열었는가.
    ///
    /// **`.onAppear` 는 탭을 다시 열 때마다 돈다.** 다른 탭에 갔다 책장으로 돌아오면
    /// 또 실행되는데, 시트를 닫으면 `detail` 이 다시 `nil` 이고 뒤로 나오면 `path` 가
    /// 다시 비어서 가드가 통과한다 — **책장에 올 때마다 상세가 다시 떴다.**
    ///
    /// 이 인자들은 **앱을 띄울 때 한 번** 보여 주려는 것이지 탭을 열 때마다가 아니다.
    ///
    /// `@State` 로 두지 않는다. 탭을 옮길 때 SwiftUI 가 이 뷰를 헐고 다시 만들면
    /// 빗장까지 함께 풀려, 고치려던 그 자리에서 다시 열린다. 앱 실행당 한 번이므로
    /// 뷰보다 오래 사는 곳에 둔다.
    private static var openedFromArguments = false

    /// `--detail` 로 첫 낱말의 상세를 펼친 채 띄운다.
    private var opensFirstDetail: Bool {
        LaunchOptions.current.has("detail")
    }

    /// `--folder=리코리스 리코일 3화` 로 그 묶음에 들어간 채 띄운다. 이름을 안 적으면
    /// 첫 묶음이다. `--detail` · `--guide` 와 같은 취지 — 시뮬레이터는 손으로 두드릴 수 없다.
    private var opensFolder: String?? {
        let launch = LaunchOptions.current
        // 이름을 적지 않은 두 가지를 같이 받는다 — `--folder` 와 `--folder=`.
        guard let name = launch.value(for: "folder") ?? (launch.has("folder") ? "" : nil)
        else { return nil }
        return name.isEmpty ? .some(collection.folderNames.first) : .some(name)
    }

    /// `--new-folder` 로 이름 받는 자리를 펼친 채 띄운다.
    /// `--detail` · `--folder=` 와 같은 취지 — 시뮬레이터는 손으로 두드릴 수 없다.
    private var opensNewFolder: Bool {
        LaunchOptions.current.has("new-folder")
    }

    private static let contentWidth: CGFloat = Theme.listWidth

    private var days: [CollectedWord.Day] { CollectedWord.byDay(collection.words) }

    /// **묶음만 남아 있어도 책장은 비어 있지 않다.** 담긴 것이 없어도 만들어 둔 자리가
    /// 있으면 그것을 보여야 한다 — 안 그러면 방금 만든 묶음이 빈 화면 뒤로 사라진다.
    private var isEmpty: Bool {
        collection.words.isEmpty && collection.folderNames.isEmpty
    }

    var body: some View {
        NavigationStack(path: $path) {
            root
                // 화면 이름은 헤더가 이미 말한다. 내비 바까지 두면 "책장"이 두 번이다.
                // 그래도 이름은 적어 둔다 — 묶음 화면의 뒤로 버튼이 이것을 가져다 쓴다.
                .navigationTitle("책장")
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
    }

    /// 묶음·날짜 하나를 펼친 화면. 목록에서 무엇을 눌렀든 도착하는 곳은 같다.
    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .folder(let name):
            FolderDetail(title: name ?? "아직 안 넣은 것",
                         words: collection.words.filter { $0.folder == name },
                         folder: name,
                         onPractice: onPractice,
                         onRename: { collection.renameFolder($0, to: $1) },
                         onRemoveFolder: { collection.removeFolder($0) },
                         onFind: onPick,
                         onRemoveWord: { collection.remove($0) },
                         onMoveWord: { collection.move($0, to: $1) },
                         folderNames: collection.folderNames)
        case .day(let date):
            FolderDetail(title: date.formatted(.dateTime.month(.wide).day().locale(Theme.locale)),
                         words: days.first { $0.date == date }?.words ?? [],
                         onPractice: onPractice,
                         onFind: onPick,
                         onRemoveWord: { collection.remove($0) },
                         onMoveWord: { collection.move($0, to: $1) },
                         folderNames: collection.folderNames)
        }
    }

    /// 건네진 묶음을 연다. **보기도 함께 맞춘다** — 날짜별을 보고 있었으면
    /// 뒤로 나왔을 때 방금 연 묶음이 목록에 없다.
    private func openIncoming() {
        guard let route = incomingFolder?.wrappedValue else { return }
        grouping = .folders
        path = [.folder(route.name)]
        incomingFolder?.wrappedValue = nil
    }

    private var root: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            // **담긴 것이 없으면 헤더도 없다.** 한때는 늘 그렸다 — 화면 이름과
            // **설정으로 가는 길**은 비어 있어도 있어야 한다는 이유였는데, 설정은 그 뒤
            // 탭바로 옮겨 갔다. 남은 것은 이름과 개수뿐이고, 둘 다 빈 화면에서는 소음이다.
            // 개수 `0` 은 알려 주는 것이 없고, 이름은 가운데 글이 "아직 **책장이** 비어
            // 있어요"로 이미 말한다 — 같은 말을 두 자리에서 하지 않는다.
            //
            // 헤더가 빠지면 빈 글이 **화면 전체의 한가운데**에 선다. 연습의 빈 화면과
            // 같은 자리다 — 탭을 오갈 때 같은 말이 위아래로 흔들리지 않는다.
            if isEmpty {
                LibraryEmptyState { naming = true }
                    .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // 헤더도 목록과 같은 폭 안에 선다. 목록만 가운데 모이고 헤더가
                    // 화면 끝에 붙으면 같은 화면의 것이 두 자리에서 시작한다.
                    header
                        .frame(maxWidth: Self.contentWidth, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    content
                }
                .transition(.opacity)
            }
        }
        // **비었다가 채워지는 자리를 잇는다.** 빈 화면에서 묶음을 만들면 판이 지는
        // 것과 동시에 화면이 통째로 갈리는데, 이어 주지 않으면 한 프레임 만에
        // 다른 화면으로 바뀌어 판이 닫힌 것인지 화면이 넘어간 것인지 읽히지 않는다.
        // 판이 뜨고 지는 결과 같은 것을 쓴다 — 한 몸짓의 앞뒤이기 때문이다.
        .animation(.dialog, value: isEmpty)
        // **탭이 서기 전에 건네진 것도 받는다.** 찾기에서 알림 줄을 누르면 묶음을
        // 건네면서 탭을 바꾸는데, 책장에 한 번도 온 적이 없으면 이 화면이 그때 처음
        // 만들어진다 — 그 경우 `onChange` 는 이미 지나간 변화를 못 본다.
        .onAppear { openIncoming() }
        .onChange(of: incomingFolder?.wrappedValue) { _, _ in openIncoming() }
        .onAppear {
            guard !Self.openedFromArguments else { return }
            Self.openedFromArguments = true
            if opensFirstDetail { detail = collection.words.first }
            if let name = opensFolder { path = [.folder(name)] }
            if opensNewFolder { naming = true }
            // `--list-picking` 은 `모두` 목록을 전부 고른 채로, `--list-moving` 은
            // 그 위에 옮기는 판까지 펼친 채로 띄운다. 묶음 화면의 `--picking` 과
            // 이름을 나눠 둔 것은 둘이 한 화면에 겹쳐 설 수 있어서다.
            let launch = LaunchOptions.current
            if launch.has("list-picking") || launch.has("list-moving") {
                grouping = .list
                // **한 박자 뒤에 켠다.** 보기를 바꾸면 손을 떼게 해 두었으므로,
                // 같은 자리에서 보기를 바꾸고 고르기를 켜면 방금 켠 것이 곧바로 풀린다.
                Task { @MainActor in
                    selecting = true
                    selection = Set(collection.words.map(\.id))
                    moving = launch.has("list-moving")
                }
            }
        }
        .sheet(item: $detail) { word in
            // **목록째 넘긴다.** 펼쳐 본 낱말은 이 목록의 한 자리이고, 옆 낱말로 가는 일은
            // 화면을 옮기는 일이 아니다 — 시트 안에서 좌우로 밀면 이웃한 낱말이 온다.
            // 옮긴 결과를 여기서 되비출 일도 없어졌다. 시트가 `collection.words` 를
            // 그대로 보고 있으므로 옮기는 즉시 그 낱말의 새 묶음이 시트에 뜬다.
            WordDetail(words: collection.words,
                       start: word.id,
                       onFind: onPick,
                       onRemove: { collection.remove($0) },
                       onMove: { collection.move($0, to: $1) },
                       folderNames: collection.folderNames)
        }
        // 이름은 **화면 한가운데 뜨는 판**으로 받는다. 아래에서 올라오는 시트는
        // "다음 화면"의 몸짓인데, 이름 한 줄을 묻는 일은 화면을 옮기는 일이 아니다.
        // 보기를 바꾸면 손을 뗀다. 묶음별에서 지우던 손과 모두에서 고르던 손이
        // 보기를 넘어 이어지면, 눌렀을 때 무엇이 지워질지 알 수 없다.
        .onChange(of: grouping) { _, _ in
            editing = false
            if selecting { endSelecting() }
        }
        // **비면 손을 뗀다.** 지우기를 켜 둔 채 마지막 묶음까지 지우면 목록이 통째로
        // 빈 화면으로 갈리는데, 켜 둔 손은 `@State` 라 그대로 살아 있다. 빈 화면에는
        // `완료` 단추가 없어(단추는 `if !isEmpty` 안에 있다) **끄는 문이 없다** —
        // 그 자리에서 묶음을 새로 만들면 목록이 지우던 모습(빨간 `−` · 만드는 줄 없음)
        // 그대로 돌아온다. 보기를 바꿀 때와 같은 규칙을 비는 순간에도 건다.
        .onChange(of: isEmpty) { _, empty in
            guard empty else { return }
            editing = false
            if selecting { endSelecting() }
        }
        .dialog(isPresented: $moving) {
            let picked = pickedFolder
            FolderChooserDialog(title: "어디로 옮길까요?",
                                hint: "고른 낱말 \(selection.count)개가 한꺼번에 가요.",
                                folderNames: collection.folderNames,
                                current: picked.name,
                                marksCurrent: picked.unanimous,
                                isPresented: $moving) { destination in
                moveSelected(to: destination)
            }
        }
        // **지우는 것만 시스템 알림으로 묻는다.** 되돌릴 수 없는 일은 앱의 얼굴보다
        // 사용자가 이미 아는 "정말요?" 얼굴이 낫다.
        .alert("고른 낱말을 지울까요?", isPresented: $removingWords) {
            Button("지우기", role: .destructive) { removeSelected() }
            Button("그만두기", role: .cancel) { }
        } message: {
            Text("\(selection.count)개를 책장에서 빼요. 되돌릴 수 없어요.")
        }
        .dialog(isPresented: $naming) {
            FolderNameDialog(title: "새 묶음",
                             hint: "보기 전에 자리를 만들어 두면, 담을 때 그 자리를 고를 수 있어요.",
                             placeholder: "예) 리코리스 리코일 4화",
                             existing: collection.folderNames,
                             isPresented: $naming) { name in
                collection.createFolder(name)
            }
        }
    }

    /// 새 묶음 이름을 받는 중인가.
    ///
    /// **목록 안에 칸을 세우지 않는다.** 담기 모달은 고르러 온 화면이라 그 자리에서
    /// 이름을 받아도 되지만, 여기는 훑는 목록이다 — 칸이 목록 한가운데 서면 키보드가
    /// 올라오며 보고 있던 줄이 밀린다.
    @State private var naming = false

    /// 줄과 줄 사이를 가르는 선.
    ///
    /// **글이 시작하는 자리에서 함께 시작한다.** 줄 안쪽에서 여백을 주는 탓에
    /// 선만 형제로 남아 기둥 끝까지 뻗었고, 목록이 글보다 넓어 보였다.
    private var rowDivider: some View {
        Theme.rule(Theme.grey3)
            .padding(.horizontal, Theme.gutter)
    }

    /// 지우는 손이 얹혔는가.
    ///
    /// **미는 몸짓 대신 편집 자리를 둔다.** 목록이 `LazyVStack` 이라 미는 몸짓을
    /// 직접 만들면 훑는 손(세로)과 지우는 손(가로)이 같은 자리에서 다툰다.
    /// 무엇보다 **지우는 일은 되돌릴 수 없으므로**, 지울 셈일 때만 단추가 보이는 편이
    /// 스치듯 지워지는 것보다 낫다.
    /// **이름이 약속을 넘지 않게 한다.** "편집"이라 적으면 이름 바꾸기·자리 옮기기까지
    /// 될 것처럼 들리는데 여기서 되는 일은 지우는 것 하나다.
    @State private var editing = false

    /// 낱말을 고르는 손이 얹혔는가. **`모두` 목록에서만 쓴다.**
    ///
    /// 묶음별에서 지우는 것은 *묶음*이고 여기서 고르는 것은 *낱말*이라, 한 상태로 묶으면
    /// 같은 단추가 보기에 따라 다른 것을 지운다. 묶음 화면의 고르기와 같은 문법이다 —
    /// 골라 두고 한꺼번에 옮기거나 지운다.
    @State private var selecting = false
    /// 고른 낱말들. 낱말 자체가 아니라 `id` 를 담는다 — 옮기고 나면 낱말의 값이
    /// 바뀌는데, 값으로 들고 있으면 옮긴 뒤에 같은 것을 못 알아본다.
    @State private var selection: Set<String> = []
    /// 고른 것을 어디로 옮길지 묻는 판.
    @State private var moving = false
    /// 고른 것을 지울지 묻는 자리. 되돌릴 수 없으므로 시스템 알림으로 묻는다.
    @State private var removingWords = false

    private var pickedWords: [CollectedWord] {
        collection.words.filter { selection.contains($0.id) }
    }
    private var allPicked: Bool {
        !collection.words.isEmpty && selection.count == collection.words.count
    }
    /// 고른 것들이 **모두 같은 자리에** 있는가. 서로 다른 묶음에서 골라 왔으면
    /// "지금"이라 찍을 자리가 없다.
    private var pickedFolder: (name: String?, unanimous: Bool) {
        let folders = Set(pickedWords.map(\.folder))
        return (folders.count == 1 ? folders.first! : nil, folders.count == 1)
    }

    private func toggle(_ word: CollectedWord) {
        if selection.contains(word.id) {
            selection.remove(word.id)
        } else {
            selection.insert(word.id)
        }
    }

    private func endSelecting() {
        withAnimation(.snappy(duration: 0.18)) {
            selecting = false
            selection = []
        }
    }

    /// 고른 것을 한꺼번에 옮긴다. **하나씩 옮기는 길과 같은 길을 쓴다** —
    /// 여기만 따로 저장하면 지난번 묶음을 건드리는지 같은 규칙이 두 벌이 된다.
    private func moveSelected(to destination: String?) {
        for word in pickedWords { collection.move(word, to: destination) }
        endSelecting()
    }

    private func removeSelected() {
        for word in pickedWords { collection.remove(word) }
        endSelecting()
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                switch grouping {
                case .folders:
                    // 담긴 것이 없는 묶음도 여기 선다. 낱말에서만 거두면 마지막 낱말을
                    // 옮기는 순간 묶음이 사라지는데, 사용자는 낱말 하나를 치웠을 뿐이다.
                    ForEach(collection.folders) { folder in
                        // 묶음을 없애도 **낱말은 남는다** — 묶음은 담아 둔 자리일 뿐이다.
                        // 그래서 여기서는 되묻지 않는다. 이름 없는 무리는 지울 자리가 없다.
                        DeletableRow(editing: editing,
                                     onRemove: { if let name = folder.name { collection.removeFolder(name) } }) {
                            LibraryGroupRow(name: folder.name ?? "아직 안 넣은 것",
                                            dim: folder.name == nil,
                                            words: folder.words,
                                            route: Route.folder(folder.name))
                        }
                        rowDivider
                    }
                    // **지울 셈일 때는 만드는 자리를 감춘다.** 한 화면에서 만들기와
                    // 지우기가 나란히 서면 손이 어느 쪽인지 헷갈린다.
                    if !editing { NewFolderRow { naming = true } }
                case .days:
                    // 날짜 묶음에는 지우는 단추를 두지 않는다. 날짜는 사람이 만든 자리가
                    // 아니라 담은 때가 만든 자리라, 지운다는 말이 성립하지 않는다.
                    ForEach(days) { day in
                        LibraryGroupRow(name: day.date.formatted(.dateTime.month(.wide).day().locale(Theme.locale)),
                                        dim: false,
                                        words: day.words,
                                        route: Route.day(day.date))
                        rowDivider
                    }
                case .list:
                    // **여기서는 지우는 대신 고른다.** 지우기만 되던 자리인데, 담아 둔
                    // 것을 손보는 일은 지우는 것보다 옮기는 것이 잦다 — 한 편을 몰아
                    // 담고 나서 갈래를 나눈다. 지우기는 고른 뒤에 할 수 있는 일로 들어갔다.
                    ForEach(collection.words) { word in
                        // 줄이 세 층(가나·한글·뜻)이라 동그라미를 가운데 두면 가운데
                        // 층에 붙는다. 글의 첫 줄에 맞춰 세운다 — 고르는 것은 낱말이고,
                        // 낱말은 맨 윗줄에 있다.
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            if selecting { SelectionMark(isPicked: selection.contains(word.id)) }
                            LibraryWordRow(word: word,
                                           selecting: selecting,
                                           isPicked: selection.contains(word.id),
                                           onTap: { if selecting { toggle(word) } else { detail = word } },
                                           onRemove: { collection.remove(word) })
                        }
                        rowDivider
                    }
                }
            }
            .frame(maxWidth: Self.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // **밀 것이 없으면 안 밀린다.** 묶음이 둘셋뿐이라 목록이 화면을 안 채우는데도
        // 당기면 화면이 통째로 따라 내려갔다가 튀어 올랐다 — "스크롤이 살짝 멈췄다
        // 되돌아온다"고 읽힌 것이 이것이다. 목록이 화면보다 길 때는 그대로 튄다.
        //
        // 세로로 미는 화면 전부에 같은 줄을 걸었다. 한 화면만 고치면 책장에서 안 튀던
        // 것이 설정에서 튀어, 같은 앱 안에서 규칙이 갈린다.
        .scrollBounceBehavior(.basedOnSize)
    }

    /// 화면의 이름과 보기 전환.
    ///
    /// 탭바에서 글자를 빼고 아이콘만 남겼으므로, **여기가 어디인지 말해 주는 것이
    /// 화면 안에 있어야 한다.** 개수를 곁들이는 것은 세어 보라는 뜻이 아니라
    /// 쌓이고 있다는 것이 보이라는 뜻이다.
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            // **고르는 중에는 이 줄이 통째로 바뀐다.** 묶음 화면과 같은 문법이다 —
            // 이름 자리에 무엇을 고르는 중인지가 서고, 그 낱말들로 할 수 있는 일이 뒤따른다.
            if selecting {
                selectionHead
            } else {
                LibraryTitleRow(wordCount: collection.words.count,
                                isEmpty: isEmpty,
                                grouping: grouping,
                                editing: $editing,
                                onStartSelecting: {
                                    withAnimation(.snappy(duration: 0.18)) { selecting = true }
                                })
            }
            // 담긴 것이 없으면 무엇으로 묶어 볼지도 없다. 고르는 중에도 감춘다 —
            // 고르다 말고 보기를 바꾸면 고른 것이 어디로 갔는지 알 수 없다.
            if !collection.words.isEmpty && !selecting { dial }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    /// 고르는 중의 머리줄. 묶음 화면과 **같은 것**을 쓴다 — `SelectionHead`.
    private var selectionHead: some View {
        SelectionHead(count: selection.count,
                      allPicked: allPicked,
                      onToggleAll: {
                          selection = allPicked ? [] : Set(collection.words.map(\.id))
                      },
                      onMove: { moving = true },
                      onRemove: { removingWords = true },
                      onDone: { endSelecting() })
    }

    /// 무엇으로 묶어 볼지 — 묶음별 · 날짜별 · 모두.
    private var dial: some View {
        HStack(spacing: 6) {
            ForEach(Grouping.allCases) { option in
                ChoiceChip(title: option.label, isSelected: option == grouping) {
                    withAnimation(.snappy(duration: 0.18)) { grouping = option }
                }
            }
        }
    }
}
