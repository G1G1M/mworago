import SwiftUI
import MworagoCore

/// 교재에서 낱말 하나를 펼쳐 본 것.
///
/// 전에는 낱말을 누르면 **찾기 탭으로 건너갔다.** 모아 둔 것을 다시 만나는 길을 내려던
/// 것인데, 대가가 있었다 — 교재에서 나가 버리니 여러 개를 훑을 때마다 돌아와야 하고,
/// 입력 바에 남아 있던 검색어가 덮여 원래 보던 것이 사라졌다.
///
/// **길을 없애는 것이 아니라 기본 동작을 바꾼다.** 누르면 여기서 펼치고,
/// 찾기로 가는 것은 버튼 하나로 남긴다.
///
/// **낱말 하나가 아니라 목록을 받는다.** 펼쳐 본 낱말은 목록 안의 한 자리이고,
/// 옆 낱말로 가는 일은 화면을 옮기는 일이 아니다 — 좌우로 밀면 이웃한 낱말이 온다.
/// 열었다 닫기를 되풀이하던 왕복이 그만큼 없어진다.
///
/// 층의 차례는 화면 어디서나 같다 — **가나 · 한글**.
struct WordDetail: View {
    /// 펼쳐 볼 수 있는 낱말들. 열린 자리의 목록 그대로다 —
    /// 책장 `모두` 에서 열었으면 모은 것 전부, 묶음에서 열었으면 그 묶음뿐이다.
    let words: [CollectedWord]
    /// 처음 보일 낱말.
    let start: CollectedWord.ID
    /// 찾기로 건너간다. 없애지 않고 버튼 하나로 남겨 둔 길이다.
    var onFind: (String) -> Void = { _ in }
    /// 교재에서 뺀다.
    var onRemove: (CollectedWord) -> Void = { _ in }
    /// 다른 묶음으로 옮긴다. 담을 때는 묻지 않는 대신, 나중에 여기서 고쳐 넣는다.
    var onMove: (CollectedWord, String?) -> Void = { _, _ in }
    /// 고를 수 있는 묶음들.
    var folderNames: [String] = []

    @Environment(\.dismiss) private var dismiss
    /// 지금 보고 있는 낱말. 넘기면 따라 바뀐다.
    ///
    /// **`id` 로 들고 있다.** 낱말 자체를 들면 묶음을 옮긴 뒤에 값이 달라져서
    /// 방금까지 보던 것을 못 알아본다 — 고르기가 `id` 를 담는 것과 같은 까닭이다.
    @State private var currentID: CollectedWord.ID?
    /// 옮길 곳을 고르는 중인가.
    ///
    /// **묶음 화면에서 여럿을 옮기는 것과 같은 판을 쓴다.** 하나를 옮기든 셋을 옮기든
    /// 하는 일이 같은데 얼굴이 다르면 문법을 두 벌 배워야 한다. 담기(찾기에서 갈피표를
    /// 누르는 자리)만 시트로 남는다 — 그쪽은 낱말을 손에 들고 와서 **새 묶음을 만들며**
    /// 담는 자리라 목록이 길고, 판보다 시트가 맞다.
    @State private var moving = false

    init(words: [CollectedWord],
         start: CollectedWord.ID,
         onFind: @escaping (String) -> Void = { _ in },
         onRemove: @escaping (CollectedWord) -> Void = { _ in },
         onMove: @escaping (CollectedWord, String?) -> Void = { _, _ in },
         folderNames: [String] = []) {
        self.words = words
        self.start = start
        self.onFind = onFind
        self.onRemove = onRemove
        self.onMove = onMove
        self.folderNames = folderNames
        _currentID = State(initialValue: start)
    }

    /// 지금 낱말. 보고 있던 것이 목록에서 사라졌으면(옮겨 가거나 빠졌으면) 첫 낱말로 돌아간다.
    private var current: CollectedWord? {
        words.first { $0.id == currentID } ?? words.first
    }

    private var position: Int? {
        currentID.flatMap { id in words.firstIndex { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            Pager(items: words, current: $currentID) { word in
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        layers(word)
                        gloss(word)
                        folderRow(word)
                        collectedAt(word)
                        actions(word)
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, Theme.screenBottom)
                    .frame(maxWidth: Theme.readWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 몇 번째를 보고 있는지. 넘길 수 있다는 것도 이것이 말해 준다.
                ToolbarItem(placement: .principal) {
                    PagerPosition(index: position, total: words.count)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .font(Theme.korean(.body))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .dialog(isPresented: $moving) {
            if let word = current {
                FolderChooserDialog(title: "어디로 옮길까요?",
                                    hint: word.reading,
                                    folderNames: folderNames,
                                    // 점은 **지금 있는 자리**를 가리킨다.
                                    current: word.folder,
                                    isPresented: $moving) { onMove(word, $0) }
            }
        }
    }

    /// 가나 · 한글. 카드와 문장이 쓰는 것과 같은 차례다.
    /// 여기서는 다이얼로 접지 않는다 — 펼쳐 보려고 연 화면이기 때문이다.
    ///
    /// **소리가 가장 큰 글자 곁에 선다.** 펼쳐 보려고 연 화면이라, 눈으로 볼 것과
    /// 귀로 들을 것이 같은 자리에 있어야 한다.
    private func layers(_ word: CollectedWord) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(word.reading)
                    .font(Theme.japanese(.display, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let 품사 = word.partOfSpeech { PartOfSpeechTag(name: 품사) }
                SpeakButton(text: word.reading, size: 18)
            }

            Text(word.hangul)
                .font(Theme.korean(.body))
                .foregroundStyle(Theme.grey3)
        }
    }

    /// **담을 때 보였던 뜻**을 그대로 붙든다. 뜻이 나중에 좋아지더라도
    /// 무엇을 보고 담았는지가 그 사람의 기억과 맞다.
    @ViewBuilder
    private func gloss(_ word: CollectedWord) -> some View {
        if !word.gloss.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("뜻")
                    .font(Theme.korean(.tag))
                    .foregroundStyle(Theme.grey3)
                Text(word.gloss)
                    .font(Theme.korean(.title))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 언제 걸렸는지. 날짜가 곧 그 화라서, 여기서도 한 번 말해 준다.
    private func collectedAt(_ word: CollectedWord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("담은 날")
                .font(Theme.korean(.tag))
                .foregroundStyle(Theme.grey3)
            Text(word.collectedAt, format: .dateTime.year().month(.wide).day().locale(Theme.locale))
                .font(Theme.korean(.body))
                .foregroundStyle(Theme.grey1)
        }
    }

    private func actions(_ word: CollectedWord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Theme.rule()

            HStack(spacing: 10) {
                Button {
                    dismiss()
                    onFind(word.hangul)
                } label: {
                    Text("찾기에서 보기")
                        .font(Theme.korean(.body))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Theme.ink, in: Capsule())
                        .foregroundStyle(Theme.paper)
                }
                .buttonStyle(.plain)

                Button {
                    onRemove(word)
                    dismiss()
                } label: {
                    Text("교재에서 빼기")
                        .font(Theme.korean(.body))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Theme.grey4, in: Capsule())
                        .foregroundStyle(Theme.grey1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 어느 묶음에 든 낱말인가.
    ///
    /// 담을 때 이미 물었지만, 그때 고른 것이 늘 맞는 것은 아니다 — 하루에 두 편을 봤거나
    /// 지난번 골라져 있던 것을 그대로 눌렀을 수 있다. 여기가 고쳐 넣는 자리다.
    private func folderRow(_ word: CollectedWord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("묶음")
                .font(Theme.korean(.tag))
                .foregroundStyle(Theme.grey2)
            // **누르면 담기와 같은 모달이 열린다.** 메뉴였을 때는 이미 있는 묶음으로만
            // 옮길 수 있어서, 새 자리로 보내려면 먼저 딴 낱말을 담아 묶음을 만들어야 했다.
            Button { moving = true } label: {
                HStack(spacing: 6) {
                    Text(word.folder ?? "아직 안 넣음")
                        .font(Theme.korean(.body))
                        .foregroundStyle(word.folder == nil ? Theme.grey3 : Theme.ink)
                    Text("옮기기")
                        .font(Theme.korean(.sub))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Theme.grey4, in: Capsule())
                        .foregroundStyle(Theme.grey1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
