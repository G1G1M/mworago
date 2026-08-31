import SwiftUI

/// 이 앱이 쓰는 자료와 그 출처.
///
/// **적어야 해서 적는 것이다.** 사전도 한자 독음도 빈도 목록도 전부 CC BY-SA 4.0 이고,
/// 그 조건은 저작자 표시와 동일조건변경허락이다. 만든 사람들의 이름이 앱 안에
/// 남아 있지 않으면 쓸 수 없는 자료들이다.
///
/// 화면을 따로 만들지 않고 도움말 안에 두었다. 탭을 하나 더 늘릴 만큼 자주 볼 것은
/// 아니지만, 어디에도 없으면 안 되기 때문이다.
struct Credits: View {

    private struct Source: Identifiable {
        let id = UUID()
        let role: String       // 앱에서 무엇을 하는가 — 이름보다 이쪽이 먼저 궁금하다
        let name: String
        let by: String
        let license: String
        let url: URL?
    }

    private static let sources: [Source] = [
        Source(role: "일본어 사전",
               name: "JMdict",
               by: "Electronic Dictionary Research and Development Group",
               license: "CC BY-SA 4.0",
               url: URL(string: "https://www.edrdg.org/jmdict/j_jmdict.html")),
        Source(role: "한자의 한국 독음",
               name: "KANJIDIC2",
               by: "Electronic Dictionary Research and Development Group",
               license: "CC BY-SA 4.0",
               url: URL(string: "https://www.edrdg.org/wiki/index.php/KANJIDIC_Project")),
        Source(role: "낱말이 얼마나 흔한지",
               name: "JESC (Japanese-English Subtitle Corpus)",
               by: "Stanford NLP · Google Brain · Rakuten Institute of Technology",
               license: "CC BY-SA 4.0",
               url: URL(string: "https://nlp.stanford.edu/projects/jesc/")),
        Source(role: "글꼴",
               name: "Zen Maru Gothic · 고운돋움",
               by: "Yoshimichi Ohira · 고운한글",
               license: "SIL Open Font License 1.1",
               url: URL(string: "https://fonts.google.com/")),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                Text("이 앱은 여러 사람이 만들어 공개한 자료 위에 서 있습니다.")
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.grey1)
                    .padding(.top, 4)

                ForEach(Self.sources) { source in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(source.role)
                            .font(Theme.korean(12))
                            .foregroundStyle(Theme.grey2)

                        if let url = source.url {
                            // 색을 바꾸지 않고 밑줄로만 알린다 — 이 앱에서 색을 쓰는 자리는
                            // 강조 하나뿐이고, 출처는 강조할 것이 아니다.
                            Link(source.name, destination: url)
                                .font(Theme.korean(16))
                                .foregroundStyle(Theme.ink)
                                .underline(pattern: .solid)
                        } else {
                            Text(source.name)
                                .font(Theme.korean(16))
                                .foregroundStyle(Theme.ink)
                        }

                        Text(source.by)
                            .font(Theme.korean(13))
                            .foregroundStyle(Theme.grey1)
                        Text(source.license)
                            .font(Theme.korean(13))
                            .foregroundStyle(Theme.grey2)
                    }
                }

                Divider().overlay(Theme.grey3)

                // 동일조건변경허락 — 받은 조건 그대로 넘긴다는 약속이다.
                // 앱에 실린 사전 색인은 JMdict 를 다시 엮은 것이라 원본과 같은 조건에 놓인다.
                Text("""
                    앱에 실린 사전 색인은 위 자료를 다시 엮은 것이라, \
                    원본과 같은 CC BY-SA 4.0 조건에 놓입니다. \
                    한국어 뜻은 기기 안의 모델로 옮긴 뒤 사람이 다듬었습니다.
                    """)
                    .font(Theme.korean(13))
                    .foregroundStyle(Theme.grey2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .navigationTitle("이 앱이 쓰는 자료")
        .navigationBarTitleDisplayMode(.inline)
    }
}
