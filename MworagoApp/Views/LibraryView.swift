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
/// 그래서 날짜 쪽을 기본으로 둔다.
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

    @State private var grouping: Grouping = .folders
    /// 새 묶음 이름을 받는 자리.
    @State private var namingFolder = false
    @State private var newFolderName = ""
    /// 펼쳐 보고 있는 낱말. 누르면 여기 담기고 상세가 열린다.
    ///
    /// `--detail` 로 첫 낱말을 펼친 채 띄울 수 있다. `--query=` · `--guide` 와 같은
    /// 취지다 — 시뮬레이터는 손으로 두드릴 수 없어 시트를 눈으로 볼 길이 없다.
    @State private var detail: CollectedWord?
    private var opensFirstDetail: Bool {
        ProcessInfo.processInfo.arguments.contains("--detail")
    }

    private static let contentWidth: CGFloat = 640

    private var days: [CollectedWord.Day] { CollectedWord.byDay(collection.words) }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if collection.words.isEmpty { empty } else { content }
        }
        .onAppear {
            if opensFirstDetail, detail == nil { detail = collection.words.first }
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
                header
                switch grouping {
                case .folders:
                    ForEach(CollectedWord.byFolder(collection.words)) { folder in
                        folderBlock(folder)
                        Divider().overlay(Theme.grey3)
                    }
                case .days:
                    ForEach(days) { day in
                        dayBlock(day)
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
                Text("교재")
                    .font(Theme.korean(24, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(collection.words.count)")
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.grey2)
            }
            dial
            currentFolderRow
        }
        .padding(.horizontal, 24)
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

    /// 지금 담는 곳.
    ///
    /// **담는 순간에 묻지 않기 위한 자리다.** 애니를 보다 낱말 하나가 걸린 그때
    /// "어느 폴더에 넣지?"를 물으면 흐름이 끊긴다. 보기 시작할 때 여기서 한 번 정해 두면
    /// 그 뒤로는 갈피표 한 번으로 끝난다 — 지금 무엇을 보고 있는지는 사용자만 안다.
    private var currentFolderRow: some View {
        HStack(spacing: 8) {
            Text("지금 담는 곳")
                .font(Theme.korean(12))
                .foregroundStyle(Theme.grey2)
            Menu {
                Button("새 묶음…") {
                    newFolderName = ""
                    namingFolder = true
                }
                if !collection.folderNames.isEmpty {
                    Divider()
                    ForEach(collection.folderNames, id: \.self) { name in
                        Button(name) { collection.setCurrentFolder(name) }
                    }
                }
                if collection.currentFolder != nil {
                    Divider()
                    Button("안 넣기") { collection.setCurrentFolder(nil) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(collection.currentFolder ?? "아직 없음")
                        .font(Theme.korean(13, weight: collection.currentFolder == nil ? .regular : .semibold))
                        .foregroundStyle(collection.currentFolder == nil ? Theme.grey3 : Theme.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.grey3)
                }
            }
            .buttonStyle(.plain)
        }
        .alert("새 묶음", isPresented: $namingFolder) {
            TextField("리코리스 리코일 3화", text: $newFolderName)
            Button("만들기") { collection.setCurrentFolder(newFolderName) }
            Button("그만두기", role: .cancel) { }
        } message: {
            Text("지금부터 담는 낱말이 이 묶음으로 갑니다.")
        }
    }

    /// 묶음 하나. 날짜 묶음과 같은 꼴이라 눈이 두 번 배우지 않아도 된다.
    private func folderBlock(_ folder: CollectedWord.Folder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(folder.name ?? "아직 안 넣은 것")
                    .font(Theme.korean(17, weight: .medium))
                    .foregroundStyle(folder.name == nil ? Theme.grey2 : Theme.ink)
                Text("\(folder.words.count)개")
                    .font(Theme.korean(13))
                    .foregroundStyle(Theme.grey3)

                Spacer(minLength: 12)

                Button { onPractice(folder.words) } label: {
                    Text("이 묶음 연습")
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.grey1)
                }
                .buttonStyle(.plain)
                .accessibilityHint("이 묶음의 낱말만 연습합니다")
            }
            FlowRow(lineSpacing: 8) {
                ForEach(folder.words) { word in
                    Button { detail = word } label: {
                        Text(word.reading)
                            .font(Theme.japanese(19))
                            .foregroundStyle(Theme.grey1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.grey4, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    /// 하루치.
    ///
    /// 그날의 낱말을 가나로만 늘어놓는다. 뜻까지 펼치면 "모두" 쪽과 같은 것이 되고,
    /// 여기서 하려는 일은 **한 화 분량을 한눈에 훑는 것**이라 소리만 보인다.
    private func dayBlock(_ day: CollectedWord.Day) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(day.date, format: .dateTime.month(.wide).day())
                    .font(Theme.korean(17, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("\(day.words.count)개")
                    .font(Theme.korean(13))
                    .foregroundStyle(Theme.grey3)

                Spacer(minLength: 12)

                Button { onPractice(day.words) } label: {
                    Text("이날 것 연습")
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.grey1)
                }
                .buttonStyle(.plain)
                .accessibilityHint("이날 모은 낱말만 연습합니다")
            }
            FlowRow(lineSpacing: 8) {
                ForEach(day.words) { word in
                    Button { detail = word } label: {
                        Text(word.reading)
                            .font(Theme.japanese(19))
                            .foregroundStyle(Theme.grey1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.grey4, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
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
                    if word.headword != word.reading {
                        Text(word.headword)
                            .font(Theme.japanese(16))
                            .foregroundStyle(Theme.grey1)
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
            .accessibilityHint("자세히 봅니다")

            Button {
                collection.remove(word)
            } label: {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(word.headword) 빼기")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("아직 교재가 없어요")
                .font(Theme.korean(22, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("찾기에서 낱말 옆의 갈피표를 누르면 여기 쌓입니다.")
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
        .frame(maxWidth: 460, alignment: .leading)
        .padding(.horizontal, 28)
    }
}
