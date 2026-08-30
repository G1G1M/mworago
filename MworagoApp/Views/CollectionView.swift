import SwiftUI
import MworagoCore

/// 모은 낱말.
///
/// 찾기 화면과 같은 결로 보인다 — 가나가 맨 위, 그 아래 한자와 한글.
/// 다른 것은 **담을 때 보였던 뜻을 그대로 붙든다**는 점이다. 뜻이 나중에 좋아지더라도
/// 무엇을 보고 담았는지가 그 사람의 기억과 맞다.
struct CollectionView: View {
    let collection: CollectionStore

    private static let contentWidth: CGFloat = 640

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            if collection.words.isEmpty {
                empty
            } else {
                list
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                ForEach(collection.words) { word in
                    row(word)
                    Divider().overlay(Theme.grey3)
                }
            }
            .frame(maxWidth: Self.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    /// 화면의 이름.
    ///
    /// 탭바에서 글자를 빼고 아이콘만 남겼으므로, **여기가 어디인지 말해 주는 것이
    /// 화면 안에 있어야 한다.** 찾기는 입력 바가 그 일을 하지만 목록은 그렇지 않다.
    /// 첫 낱말이 상태 표시줄에 바로 붙던 것도 함께 풀린다.
    ///
    /// 개수를 곁들이는 것은 세어 보라는 뜻이 아니라, 쌓이고 있다는 것이 보이라는 뜻이다.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("모은 것")
                .font(Theme.korean(24, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("\(collection.words.count)")
                .font(Theme.korean(15))
                .foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private func row(_ word: CollectedWord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
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
            Spacer(minLength: 12)
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
            Text("아직 모은 것이 없어요")
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
        }
        .frame(maxWidth: 460, alignment: .leading)
        .padding(.horizontal, 28)
    }
}
