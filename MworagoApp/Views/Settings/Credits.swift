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
        /// 라이선스 원문이 있는 자리. **이것이 빠지면 조건을 안 지킨 것이다** —
        /// CC BY-SA 4.0 은 "라이선스 본문 또는 그 주소를 함께 실으라"고 못 박는다
        /// (3(a)(1)). 자료로 가는 링크는 "합리적으로 가능한 범위"라는 단서가 붙지만,
        /// 이쪽에는 단서가 없다.
        let licenseURL: URL?
        let url: URL?
    }

    /// **자료를 실제로 받을 수 있는 자리.**
    ///
    /// 동일조건변경허락(CC BY-SA 4.0 의 SA)은 "같은 조건으로 내놓아라"까지가 조건이다.
    /// "같은 조건에 놓입니다"라고 적어 두기만 하면 받는 쪽이 그것을 실제로 손에 넣을
    /// 길이 없어 조건을 지킨 것이 아니다.
    ///
    /// **색인 파일 자체는 저 자리에 없다.** 40MB 짜리라 저장소에 두지 않는다
    /// (`.gitignore`). 대신 원본을 받는 스크립트(`Tools/fetch`)와 그것으로 색인을
    /// 굽는 도구(`Tools/bake/build-index.sh`)가 있어, 받는 쪽이 같은 것을 다시 만들 수
    /// 있다. **화면 문구도 그렇게 적는다** — "색인이 여기 있다"고 적어 두고 가 보면
    /// 없는 것은, 안 적어 둔 것보다 나쁘다.
    ///
    /// **열려 있는 것을 확인했다(2026-09-06).** 레포를 공개로 돌렸다. 이 주소가
    /// 닫히면 조건을 지키지 못하는 것이므로, 옮길 때는 이 한 줄도 함께 옮긴다
    /// (`Settings.feedbackAddress` 와 같은 규칙이다).
    private static let sourceAddress = URL(string: "https://github.com/G1G1M/mworago")

    /// **개인정보 처리방침 원문이 있는 자리.**
    ///
    /// 심사 지침 5.1.1 은 방침 링크를 App Store Connect 칸에 **그리고 앱 안에서 쉽게
    /// 닿는 자리에** 두라고 한다. 아래 「개인정보」 절은 요약이라, 지침이 방침에
    /// 적으라고 못 박은 셋 — 무엇을 모으는가 · 제3자와 어떻게 나누는가 · 보관과
    /// 삭제와 동의 철회 — 을 다 담지 않는다. 그것은 `docs/privacy.md` 에 있다.
    ///
    /// `sourceAddress` 와 같은 규칙이다 — 이 주소가 닫히면 지침을 지키지 못하는
    /// 것이므로, 저장소를 옮길 때는 이 한 줄도 함께 옮긴다.
    private static let privacyAddress =
        URL(string: "https://github.com/G1G1M/mworago/blob/main/docs/privacy.md")

    private static let sources: [Source] = [
        Source(role: "일본어 사전",
               name: "JMdict",
               by: "Electronic Dictionary Research and Development Group",
               license: "CC BY-SA 4.0",
               licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/"),
               url: URL(string: "https://www.edrdg.org/jmdict/j_jmdict.html")),
        Source(role: "한자의 한국 독음",
               name: "KANJIDIC2",
               by: "Electronic Dictionary Research and Development Group",
               license: "CC BY-SA 4.0",
               licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/"),
               url: URL(string: "https://www.edrdg.org/wiki/index.php/KANJIDIC_Project")),
        Source(role: "낱말이 얼마나 흔한지",
               name: "JESC (Japanese-English Subtitle Corpus)",
               by: "Stanford NLP · Google Brain · Rakuten Institute of Technology",
               license: "CC BY-SA 4.0",
               licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/"),
               url: URL(string: "https://nlp.stanford.edu/projects/jesc/")),
        Source(role: "글꼴",
               name: "Zen Maru Gothic · 고운돋움",
               by: "Yoshimichi Ohira · 고운한글",
               license: "SIL Open Font License 1.1",
               licenseURL: URL(string: "https://openfontlicense.org/"),
               url: URL(string: "https://fonts.google.com/")),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                Text("이 앱은 여러 사람이 공개해 둔 자료로 만들어졌습니다.")
                    .font(Theme.korean(.body))
                    .foregroundStyle(Theme.grey1)
                    .padding(.top, 4)

                ForEach(Self.sources) { source in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(source.role)
                            .font(Theme.korean(.tag))
                            .foregroundStyle(Theme.grey2)

                        if let url = source.url {
                            // 색을 바꾸지 않고 밑줄로만 알린다 — 이 앱에서 색을 쓰는 자리는
                            // 강조 하나뿐이고, 출처는 강조할 것이 아니다.
                            Link(source.name, destination: url)
                                .font(Theme.korean(.title))
                                .foregroundStyle(Theme.ink)
                                .underline(pattern: .solid)
                        } else {
                            Text(source.name)
                                .font(Theme.korean(.title))
                                .foregroundStyle(Theme.ink)
                        }

                        Text(source.by)
                            .font(Theme.korean(.sub))
                            .foregroundStyle(Theme.grey1)
                        // **누를 수 있어야 조건을 지킨 것이다.** 이름만 적어 두면
                        // 그 라이선스가 무엇을 요구하는지 읽을 길이 없다.
                        if let licenseURL = source.licenseURL {
                            Link(source.license, destination: licenseURL)
                                .font(Theme.korean(.sub))
                                .foregroundStyle(Theme.grey2)
                                .underline(pattern: .solid)
                        } else {
                            Text(source.license)
                                .font(Theme.korean(.sub))
                                .foregroundStyle(Theme.grey2)
                        }
                    }
                }

                Theme.rule()

                // 동일조건변경허락 — 받은 조건 그대로 넘긴다는 약속이다.
                // 앱에 실린 사전 색인은 JMdict 를 다시 엮은 것이라 원본과 같은 조건에 놓인다.
                //
                // **"기기 안의 모델"이라고 적혀 있었다.** 앱 안에는 모델이 없다 —
                // 뜻은 만드는 쪽에서 미리 옮겨 색인에 구워 넣은 것이고, 앱은 그 파일만 읽는다.
                // 심사에 걸릴 말은 아니지만 사용자에게 사실과 다르게 말하고 있었다.
                VStack(alignment: .leading, spacing: 7) {
                    Text("""
                        앱에 실린 사전 색인은 위 자료를 다시 엮은 것이라, \
                        원본과 같은 CC BY-SA 4.0 조건에 놓입니다. \
                        한국어 뜻은 미리 옮겨 실은 것이고, 자주 쓰는 낱말은 사람이 다듬었습니다.
                        """)
                        .font(Theme.korean(.sub))
                        .foregroundStyle(Theme.grey2)
                        .fixedSize(horizontal: false, vertical: true)

                    // **받을 자리를 함께 밝힌다.** 같은 조건에 놓인다는 말만으로는
                    // 동일조건변경허락을 지킨 것이 아니다 — 받는 쪽이 손에 넣을 길이 있어야 한다.
                    if let address = Self.sourceAddress {
                        Link(destination: address) {
                            Text("색인을 만드는 도구와 원본 받는 길이 여기에 있습니다")
                                .font(Theme.korean(.sub))
                                .foregroundStyle(Theme.grey1)
                                .underline(pattern: .solid)
                        }
                    }
                }

                Theme.rule()

                // 개인정보 처리방침. 모으는 것이 없으면 방침도 짧아야 한다 —
                // 아무것도 안 한다는 말을 길게 쓰면 오히려 무언가 하는 것처럼 읽힌다.
                VStack(alignment: .leading, spacing: 7) {
                    Text("개인정보")
                        .font(Theme.korean(.title))
                        .foregroundStyle(Theme.ink)
                    Text("""
                        이 앱은 아무것도 모으지 않습니다. 계정도, 위치도, 사용 기록도 \
                        받지 않고 어디로도 보내지 않습니다.
                        """)
                        .font(Theme.korean(.sub))
                        .foregroundStyle(Theme.grey1)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("""
                        사전은 앱 안에 통째로 들어 있어 찾을 때 인터넷을 쓰지 않습니다. \
                        모은 낱말은 기기 안 파일에만 있고, 앱을 지우면 함께 사라집니다.
                        """)
                        .font(Theme.korean(.sub))
                        .foregroundStyle(Theme.grey2)
                        .fixedSize(horizontal: false, vertical: true)

                    // **위는 요약이고 원문은 밖에 있다.** 요약만 두면 보관·삭제·철회를
                    // 어디서 읽는지 알 길이 없다. 자료 절의 링크와 같은 꼴로 둔다.
                    if let address = Self.privacyAddress {
                        Link(destination: address) {
                            Text("개인정보 처리방침 전문이 여기에 있습니다")
                                .font(Theme.korean(.sub))
                                .foregroundStyle(Theme.grey1)
                                .underline(pattern: .solid)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, Theme.screenBottom)
            .frame(maxWidth: Theme.readWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .koreanNavigationTitle("이 앱이 쓰는 자료")
        .scrollBounceBehavior(.basedOnSize)
    }
}
