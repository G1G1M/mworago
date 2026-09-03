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
    let collection: CollectionStore
    /// 상세에서 "찾기에서 보기"를 눌렀을 때 건너가는 길.
    ///
    /// 전에는 **낱말을 누르는 것 자체가** 이 길이었다. 모아 둔 것을 다시 만나게 하려던
    /// 것인데, 교재에서 나가 버리니 여러 개를 훑을 때마다 돌아와야 했다.
    /// 이제 누르면 상세가 열리고, 이 길은 그 안의 버튼으로 남는다.
    var onPick: (String) -> Void = { _ in }
    /// 그날 것만 들고 연습으로 건너간다. 연습이 늘 전체를 훑으면
    /// 스무 날치가 쌓인 뒤에는 오늘 본 것을 다시 만나기까지 한참이 걸린다.
    var onPractice: ([CollectedWord]) -> Void = { _ in }

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

    /// 설정. `--settings` 로 펼친 채 띄운다.
    private var opensFirstDetail: Bool {
        ProcessInfo.processInfo.arguments.contains("--detail")
    }

    /// `--folder=리코리스 리코일 3화` 로 그 묶음에 들어간 채 띄운다. 이름을 안 적으면
    /// 첫 묶음이다. `--detail` · `--guide` 와 같은 취지 — 시뮬레이터는 손으로 두드릴 수 없다.
    private var opensFolder: String?? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--folder") })
        else { return nil }
        let name = arg.hasPrefix("--folder=") ? String(arg.dropFirst("--folder=".count)) : ""
        return name.isEmpty ? .some(collection.folderNames.first) : .some(name)
    }

    /// `--new-folder` 로 이름 받는 자리를 펼친 채 띄운다.
    /// `--detail` · `--folder=` 와 같은 취지 — 시뮬레이터는 손으로 두드릴 수 없다.
    private var opensNewFolder: Bool {
        ProcessInfo.processInfo.arguments.contains("--new-folder")
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
                empty
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
        .onAppear {
            guard !Self.openedFromArguments else { return }
            Self.openedFromArguments = true
            if opensFirstDetail { detail = collection.words.first }
            if let name = opensFolder { path = [.folder(name)] }
            if opensNewFolder { naming = true }
            // `--list-picking` 은 `모두` 목록을 전부 고른 채로, `--list-moving` 은
            // 그 위에 옮기는 판까지 펼친 채로 띄운다. 묶음 화면의 `--picking` 과
            // 이름을 나눠 둔 것은 둘이 한 화면에 겹쳐 설 수 있어서다.
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--list-picking") || arguments.contains("--list-moving") {
                grouping = .list
                // **한 박자 뒤에 켠다.** 보기를 바꾸면 손을 떼게 해 두었으므로,
                // 같은 자리에서 보기를 바꾸고 고르기를 켜면 방금 켠 것이 곧바로 풀린다.
                Task { @MainActor in
                    selecting = true
                    selection = Set(collection.words.map(\.id))
                    moving = arguments.contains("--list-moving")
                }
            }
        }
        .sheet(item: $detail) { word in
            WordDetail(word: word,
                       onFind: onPick,
                       onRemove: { collection.remove($0) },
                       onMove: { word, folder in
                           collection.move(word, to: folder)
                           detail = collection.words.first { $0.id == word.id }
                       },
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
                                hint: "고른 낱말 \(selection.count)개가 한꺼번에 갑니다.",
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
            Text("\(selection.count)개를 책장에서 뺍니다. 되돌릴 수 없어요.")
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
        Divider()
            .overlay(Theme.grey3)
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

    /// 고르는 중인 줄 앞에 서는 동그라미.
    private func checkmark(_ word: CollectedWord) -> some View {
        let picked = selection.contains(word.id)
        return Image(systemName: picked ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 21))
            .foregroundStyle(picked ? Theme.ink : Theme.grey3)
            .padding(.leading, Theme.gutter)
            .accessibilityHidden(true)   // 줄 전체가 이미 고르는 단추다
    }

    /// 지울 수 있는 줄. 편집 중일 때만 단추가 앞에 선다.
    @ViewBuilder
    private func deletable<V: View>(_ remove: @escaping () -> Void,
                                    @ViewBuilder _ inner: () -> V) -> some View {
        HStack(spacing: 0) {
            if editing {
                Button(action: remove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(.red)
                        .padding(.leading, Theme.gutter)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("지우기")
            }
            inner()
        }
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
                        deletable({ if let name = folder.name { collection.removeFolder(name) } }) {
                            groupRow(name: folder.name ?? "아직 안 넣은 것",
                                     dim: folder.name == nil,
                                     words: folder.words,
                                     route: .folder(folder.name))
                        }
                        rowDivider
                    }
                    // **지울 셈일 때는 만드는 자리를 감춘다.** 한 화면에서 만들기와
                    // 지우기가 나란히 서면 손이 어느 쪽인지 헷갈린다.
                    if !editing { newFolderRow }
                case .days:
                    // 날짜 묶음에는 지우는 단추를 두지 않는다. 날짜는 사람이 만든 자리가
                    // 아니라 담은 때가 만든 자리라, 지운다는 말이 성립하지 않는다.
                    ForEach(days) { day in
                        groupRow(name: day.date.formatted(.dateTime.month(.wide).day().locale(Theme.locale)),
                                 dim: false,
                                 words: day.words,
                                 route: .day(day.date))
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
                            if selecting { checkmark(word) }
                            row(word)
                        }
                        rowDivider
                    }
                }
            }
            .frame(maxWidth: Self.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
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
            if selecting { selectionHead } else { titleRow }
            // 담긴 것이 없으면 무엇으로 묶어 볼지도 없다. 고르는 중에도 감춘다 —
            // 고르다 말고 보기를 바꾸면 고른 것이 어디로 갔는지 알 수 없다.
            if !collection.words.isEmpty && !selecting { dial }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    /// 화면 이름과, 이 목록에서 손볼 수 있는 것.
    private var titleRow: some View {
        Group {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("책장")
                    .font(Theme.korean(24, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                // 개수는 담긴 낱말을 센다. **`0` 은 적지 않는다** — 묶음만 만들어 둔
                // 책장에서 알려 주는 것이 없고, 빈 자리를 세어 보라는 말처럼 읽힌다.
                if !collection.words.isEmpty {
                    Text("\(collection.words.count)")
                        .font(Theme.korean(15))
                        .foregroundStyle(Theme.grey2)
                }

                Spacer(minLength: 12)

                // **보기마다 손볼 것이 다르다.** 묶음별에서 지우는 것은 묶음이고,
                // 모두에서 손보는 것은 낱말이다. 날짜는 사람이 만든 자리가 아니라
                // 담은 때가 만든 자리라 지울 것도 고를 것도 없다 —
                // 예전에는 거기서도 단추가 떠 있었지만 눌러도 아무 일이 없었다.
                if !isEmpty {
                    switch grouping {
                    case .folders:
                        Button {
                            withAnimation(.snappy(duration: 0.18)) { editing.toggle() }
                        } label: {
                            Text(editing ? "완료" : "지우기")
                                .font(Theme.korean(15, weight: editing ? .medium : .regular))
                                .foregroundStyle(editing ? Theme.ink : Theme.grey2)
                        }
                        .buttonStyle(.plain)
                    case .list:
                        Button {
                            withAnimation(.snappy(duration: 0.18)) { selecting = true }
                        } label: {
                            Text("고르기")
                                .font(Theme.korean(15))
                                .foregroundStyle(Theme.grey2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("낱말을 골라 옮기거나 지웁니다")
                    case .days:
                        EmptyView()
                    }
                }
            }
        }
    }

    /// 고르는 중의 머리줄. 묶음 화면의 그것과 같은 꼴이다.
    private var selectionHead: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(selection.isEmpty ? "고를 낱말을 누르세요" : "\(selection.count)개 골랐어요")
                .font(Theme.korean(17, weight: selection.isEmpty ? .regular : .semibold))
                .foregroundStyle(selection.isEmpty ? Theme.grey2 : Theme.ink)
                .lineLimit(1)

            Spacer(minLength: 10)

            headButton(allPicked ? "모두 풀기" : "모두") {
                selection = allPicked ? [] : Set(collection.words.map(\.id))
            }
            // 고른 것이 없으면 옮길 것도 지울 것도 없다. 눌러 보고 알게 하지 않는다.
            headButton("옮기기", filled: true, disabled: selection.isEmpty) { moving = true }
            headButton("지우기", destructive: true, disabled: selection.isEmpty) {
                removingWords = true
            }
            headButton("마치기") { endSelecting() }
        }
    }

    /// 머리줄의 단추. 강조는 반전 하나로만 — 지금 하려던 일이 채워진다.
    private func headButton(_ title: String, filled: Bool = false, destructive: Bool = false,
                            disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.korean(13.5, weight: filled ? .medium : .regular))
                .padding(.horizontal, filled ? 14 : 6)
                .padding(.vertical, filled ? 8 : 0)
                .background(filled ? Theme.ink : .clear, in: Capsule())
                .foregroundStyle(filled ? Theme.paper : (destructive ? Color.red : Theme.grey1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    /// 읽기 보조 다이얼과 같은 문법이다 — 평평하고, 고른 것 하나만 검게 채워진다.
    /// 유리는 씌우지 않는다. 그것은 **떠 있는** 컨트롤의 표시인데 이쪽은 글에 붙어 있다.
    private var dial: some View {
        HStack(spacing: 6) {
            ForEach(Grouping.allCases) { option in
                let selected = option == grouping
                Button {
                    withAnimation(.snappy(duration: 0.18)) { grouping = option }
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
    }

    /// 묶음 한 줄 — 묶음이든 날짜든 같은 꼴이다. 눈이 두 번 배우지 않아도 된다.
    ///
    /// **한 줄 안에서 끝난다.** 이름과 개수만 두면 스무 편도 한 화면에 들어오지만
    /// 이름만으로는 "어느 화였지"가 안 떠오른다. 그래서 오른쪽에 **낱말 두 개를 회색으로
    /// 흘려** 둔다 — 읽으라고 두는 것이 아니라 어느 무리인지 짚어 주는 단서다.
    private func groupRow(name: String, dim: Bool, words: [CollectedWord],
                          route: Route) -> some View {
        NavigationLink(value: route) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(name)
                    .font(Theme.korean(17, weight: .medium))
                    .foregroundStyle(dim ? Theme.grey2 : Theme.ink)
                Text("\(words.count)")
                    .font(Theme.korean(13))
                    .foregroundStyle(Theme.grey3)

                Spacer(minLength: 12)

                // 담긴 것이 없으면 흘릴 낱말도 없다. 그 자리를 비워 두면 줄이 반쯤
                // 지워진 것처럼 보이므로, 비었다고 적는다.
                if words.isEmpty {
                    Text("비어 있음")
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.grey3)
                } else {
                    Text(words.prefix(2).map(\.reading).joined(separator: " · "))
                        .font(Theme.japanese(13))
                        .foregroundStyle(Theme.grey3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.grey3)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("이 묶음을 엽니다")
    }

    /// 묶음을 만드는 줄. 묶음들이 선 목록의 맨 끝에 이어 붙는다.
    ///
    /// **담기 모달에도 만드는 길이 있지만 하는 일이 다르다.** 그쪽은 낱말을 손에 들고
    /// 만드는 것이라 만들면 곧 담긴다. 여기서 만드는 것은 **비어 있는 자리**다 —
    /// 다음 화를 보기 전에 이름을 세워 두고, 담을 때 그 자리를 고른다.
    private var newFolderRow: some View {
        Button { naming = true } label: {
            HStack(spacing: 11) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16)
                Text("새 묶음 만들기")
                    .font(Theme.korean(16))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.grey1)
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("담긴 것이 없는 묶음을 미리 만듭니다")
    }

    /// 낱말 하나. **담을 때 보였던 뜻을 그대로 붙든다** — 뜻이 나중에 좋아지더라도
    /// 무엇을 보고 담았는지가 그 사람의 기억과 맞다.
    private func row(_ word: CollectedWord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Button {
                if selecting { toggle(word) } else { detail = word }
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(word.reading)
                            .font(Theme.japanese(24, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        if let 품사 = word.partOfSpeech { PartOfSpeechTag(name: 품사) }
                    }
                    Text(word.hangul)
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.grey3)
                    if !word.gloss.isEmpty {
                        Text(word.gloss)
                            .font(Theme.korean(14))
                            .foregroundStyle(Theme.grey1)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(selecting ? "고르거나 풉니다" : "자세히 봅니다")
            .accessibilityAddTraits(selecting && selection.contains(word.id) ? [.isSelected] : [])

            // 고르는 중에는 갈피표를 감춘다. 한 줄에 고르는 손과 빼는 손이 같이 있으면
            // 고르려다 빼는 일이 생기고, 그것은 되돌릴 수 없다.
            if !selecting {
                Button {
                    collection.remove(word)
                } label: {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(word.reading) 빼기")
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 16)
    }

    /// 담긴 것이 없을 때. 남은 자리 한가운데 글 덩어리 하나가 선다 —
    /// 연습의 빈 화면과 같은 자리다. 글줄은 왼쪽에서 시작한다.
    ///
    /// 좌우 여백을 폭 **안쪽**에 둔다. 폭을 잰 뒤에 붙이면 덩어리가
    /// `readWidth + 여백` 이 되어 재 둔 폭이 실제와 어긋난다.
    /// 담긴 것이 없을 때. **연습의 빈 화면과 같은 자리에 선다** — 화면 한가운데
    /// 글 덩어리 하나가 가운데 정렬로 놓인다. 빈 화면은 읽으라고 두는 것이라
    /// 목록처럼 위에서부터 왼쪽에 채울 것이 없다.
    ///
    /// 두 화면이 **같은 문법으로 선다** — 폭 안쪽 여백 · `readWidth` · 공유 높이 ·
    /// 남은 자리 채우기. 결과만 비슷하게 맞춰 두면 한쪽을 손볼 때 다시 어긋난다.
    private var empty: some View {
        VStack(alignment: .leading, spacing: Theme.blockGap) {
            VStack(alignment: .leading, spacing: 12) {
                Text("아직 책장이 비어 있어요")
                    .font(Theme.korean(22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("찾기에서 낱말 옆의 갈피표를 누르면, 어느 묶음에 넣을지 물어보고 여기 쌓입니다.")
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.grey2)
            }
            // 온보딩 2장과 같은 이유로 낡았던 말이다. 날짜는 어느 화를 봤는지 앱이
            // 몰라서 쓰던 대용품인데, 이제 담을 때 어느 묶음에 넣을지 직접 고른다.
            Text("묶음은 마음대로 만들고, 담은 뒤에도 옮길 수 있어요.")
                .font(Theme.korean(13))
                .foregroundStyle(Theme.grey3)

            // **보기 전에 자리를 먼저 만들 수 있다.**
            //
            // 한때는 이 자리를 비워 두었다 — 처음 온 사람에게 할 일을 둘 내밀면
            // "찾기에서 갈피표를 누르세요"가 흐려진다는 이유였다. 그런데 다음 화를 보기
            // 전에 이름을 세워 두는 일이 이 앱의 실제 흐름이고(빈 묶음을 지원하는 까닭이
            // 그것이다), 담긴 것이 없을 때는 그 길이 아예 없었다.
            //
            // 그래서 두되 **작게** 둔다. 채우지 않은 알약이라 위의 글과 겨루지 않는다.
            Button { naming = true } label: {
                Text("묶음 만들어 두기")
                    .font(Theme.korean(14))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Theme.grey4, in: Capsule())
                    .foregroundStyle(Theme.grey1)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, Theme.gutter)
        .frame(maxWidth: Theme.readWidth, alignment: .leading)
        // 첫 줄을 연습의 빈 화면과 같은 높이에 세운다 — 자세한 까닭은 `emptyBlockHeight`.
        .frame(minHeight: Theme.emptyBlockHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
