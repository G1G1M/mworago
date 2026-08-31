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

    private static let contentWidth: CGFloat = Theme.listWidth

    private var days: [CollectedWord.Day] { CollectedWord.byDay(collection.words) }

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
            FolderDetail(title: date.formatted(.dateTime.month(.wide).day()),
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
            // **헤더는 늘 그린다.** 담긴 것이 없어도 화면 이름과 설정으로 가는 길은
            // 있어야 한다 — 처음 온 사람이야말로 이 앱이 무엇을 쓰는지 궁금할 수 있다.
            VStack(alignment: .leading, spacing: 0) {
                // 헤더도 목록과 같은 폭 안에 선다. 목록만 가운데 모이고 헤더가
                // 화면 끝에 붙으면 같은 화면의 것이 두 자리에서 시작한다.
                header
                    .frame(maxWidth: Self.contentWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                if collection.words.isEmpty { empty } else { content }
            }
        }
        .onAppear {
            if opensFirstDetail, detail == nil { detail = collection.words.first }
            if let name = opensFolder, path.isEmpty { path = [.folder(name)] }
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
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                switch grouping {
                case .folders:
                    ForEach(CollectedWord.byFolder(collection.words)) { folder in
                        groupRow(name: folder.name ?? "아직 안 넣은 것",
                                 dim: folder.name == nil,
                                 words: folder.words,
                                 route: .folder(folder.name))
                        Divider().overlay(Theme.grey3)
                    }
                case .days:
                    ForEach(days) { day in
                        groupRow(name: day.date.formatted(.dateTime.month(.wide).day()),
                                 dim: false,
                                 words: day.words,
                                 route: .day(day.date))
                        Divider().overlay(Theme.grey3)
                    }
                case .list:
                    ForEach(collection.words) { word in
                        row(word)
                        Divider().overlay(Theme.grey3)
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
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("책장")
                    .font(Theme.korean(24, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(collection.words.count)")
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.grey2)

            }
            // 담긴 것이 없으면 무엇으로 묶어 볼지도 없다.
            //
            // **"지금 담는 곳"은 여기 있었다.** 담을 때 묻지 않으려고 미리 정해 두는
            // 자리였는데, 이제 갈피표를 누르면 담기 모달이 묻는다 — 같은 것을 정하는
            // 자리가 둘이면 어느 쪽이 이기는지 사용자가 알 수 없다.
            if !collection.words.isEmpty { dial }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 18)
        .padding(.bottom, 14)
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

                Text(words.prefix(2).map(\.reading).joined(separator: " · "))
                    .font(Theme.japanese(13))
                    .foregroundStyle(Theme.grey3)
                    .lineLimit(1)
                    .truncationMode(.tail)
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

    /// 낱말 하나. **담을 때 보였던 뜻을 그대로 붙든다** — 뜻이 나중에 좋아지더라도
    /// 무엇을 보고 담았는지가 그 사람의 기억과 맞다.
    private func row(_ word: CollectedWord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Button { detail = word } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(word.reading)
                        .font(Theme.japanese(24, weight: .medium))
                        .foregroundStyle(Theme.ink)
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
            .accessibilityHint("자세히 봅니다")

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
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 16)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("아직 책장이 비어 있어요")
                .font(Theme.korean(22, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("찾기에서 낱말 옆의 갈피표를 누르면, 어느 묶음에 넣을지 물어보고 여기 쌓입니다.")
                .font(Theme.korean(15))
                .foregroundStyle(Theme.grey2)
            HStack(spacing: 7) {
                Image(systemName: "bookmark")
                    .font(.system(size: 14))
                Text("이 표시예요")
                    .font(Theme.korean(13))
            }
            .foregroundStyle(Theme.grey3)
            .padding(.top, 2)
            Text("애니 한 화를 보며 찾은 것들은 같은 날 모이니, 날짜가 곧 그 화가 됩니다.")
                .font(Theme.korean(13))
                .foregroundStyle(Theme.grey3)
                .padding(.top, 6)
        }
        .frame(maxWidth: Theme.readWidth, alignment: .leading)
        .padding(.horizontal, Theme.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 40)
    }
}
