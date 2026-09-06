import SwiftUI
import UIKit

/// 의견을 보내는 자리.
///
/// **틀린 것을 말할 곳이다.** 이 앱이 내놓는 것은 사전과 규칙이 함께 만들어 낸 답이라
/// 틀리는 자리가 반드시 있다 — 뜻이 어긋나거나, 문장이 엉뚱하게 갈리거나, 소리가 안
/// 맞는다. 그것을 본 사람만 아는 일이다.
///
/// **설정 안에 줄로 늘어놓지 않고 화면 하나로 뺐다.** 보내는 길이 둘이고 둘의 차이를
/// 말해 줘야 하는데(하나는 이름이 함께 가고 하나는 안 간다), 그 설명까지 설정 목록에
/// 늘어놓으면 `모습` 고르개 옆에 문단이 붙는다. 고르는 일이 있는 자리는 제 화면을
/// 갖는 편이 낫다 — `이 앱이 쓰는 자료` 와 같은 결이다.
struct Feedback: View {

    /// 의견을 받을 자리. **앱을 내려면 여기를 만든 사람의 주소로 바꾼다** —
    /// 앱스토어의 지원 연락처와 같은 것이어야 한다.
    static let address = "kjw100404@gmail.com"

    /// **이름 없이 보낼 자리.** 메일은 보내는 주소가 함께 가므로, 오탈자 하나를
    /// 알려 주려던 사람도 제 주소를 내놓아야 한다. 말하기를 접는 쪽이 되기 쉽다.
    ///
    /// 서버를 세우지는 않는다 — 세우는 순간 "아무것도 안 보냅니다"가 거짓이 된다.
    /// 대신 **밖에 있는 폼**을 브라우저로 연다. 앱이 스스로 보내는 것은 없고,
    /// 무엇을 적을지는 그 화면에서 사용자가 정한다.
    ///
    /// 로그인 없이 열리고 이메일을 걷지 않는 것을 확인했다. 비워 두면 그 줄은 서지
    /// 않는다 — 눌러도 아무 데도 가지 않는 줄을 두는 것보다 없는 편이 낫다.
    static let form = URL(string: "https://forms.gle/pjN4z7L8Sa3ZNL4T9")

    /// 앱 버전. 설정의 `버전` 줄과 메일 본문이 **같은 값을 봐야 한다** —
    /// 두 자리에서 따로 읽으면 사용자가 화면에서 본 것과 다른 것이 보내진다.
    static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    @State private var copiedAddress = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("""
                    이 앱이 내놓는 답은 사전과 규칙이 함께 만든 것이라 틀리는 자리가 \
                    반드시 있습니다. 무엇을 치고 무엇이 나왔는지 알려 주시면 고칩니다.
                    """)
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.grey1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 0) {
                    // **메일이 먼저다.** 주고받을 수 있는 것은 이쪽뿐이라, 무엇이
                    // 어떻게 나왔는지 되물을 수 있다.
                    Button(action: sendMail) {
                        way(title: "메일로 보내기",
                            detail: "앱 버전과 기기가 본문에 미리 적힙니다. 보내는 분의 메일 주소가 함께 갑니다.")
                    }
                    .buttonStyle(.plain)

                    if copiedAddress {
                        // 메일 앱이 없을 때. 주소를 보여 주기만 하면 옮겨 적어야 하므로
                        // 붙여 넣을 수 있게 해 두고 그 사실만 알린다.
                        Text("메일 앱을 열 수 없어 주소를 복사했습니다 — \(Self.address)")
                            .font(Theme.korean(12))
                            .foregroundStyle(Theme.grey2)
                            .padding(.bottom, 14)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let form = Self.form {
                        Divider().overlay(Theme.grey3)
                        Link(destination: form) {
                            way(title: "이름 없이 보내기",
                                detail: "브라우저로 의견 폼이 열립니다. 이름도 메일 주소도 묻지 않습니다.")
                        }
                        .buttonStyle(.plain)
                    }
                }

                // **무엇을 적어야 할지 알려 준다.** "의견을 보내 주세요"만 두면 무엇을
                // 적어야 할지 몰라 대개 "안 돼요" 한 줄이 온다. 그 한 줄로는 고칠 수 없다.
                VStack(alignment: .leading, spacing: 7) {
                    Text("이렇게 적어 주시면 가장 빠릅니다")
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.ink)
                    Text("""
                        무엇을 치셨는지 · 무엇이 나왔는지 · 무엇이 나오길 기대하셨는지.
                        친 글자를 그대로 적어 주시면 같은 자리를 다시 만들어 볼 수 있습니다.
                        """)
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.grey2)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, Theme.screenBottom)
            .frame(maxWidth: Theme.readWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .koreanNavigationTitle("의견 보내기")
        .scrollBounceBehavior(.basedOnSize)
    }

    /// 보내는 길 한 줄. 제목 아래에 **무엇이 다른지**가 붙는다 —
    /// 둘을 나란히 놓기만 하면 왜 둘인지를 사용자가 짐작해야 한다.
    private func way(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.korean(16))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(Theme.korean(12))
                    .foregroundStyle(Theme.grey2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.grey3)
                .padding(.top, 4)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    /// 메일 앱을 연다. **무엇이 적혀 나가는지 사용자가 먼저 본다** —
    /// 앱이 몰래 보내는 것이 하나도 없다는 것이 이 앱의 약속이다.
    ///
    /// 본문에 버전과 기기를 적어 두는 것은, 같은 낱말이 기기마다 다르게 나오는 일이
    /// 있어서다(번역기 언어팩이 그렇다). 사용자가 지우고 보내도 된다.
    private func sendMail() {
        let 본문 = """


            ─────────────
            무엇이 어떻게 나왔는지 적어 주세요. 친 글자와 화면을 함께 알려 주시면 좋습니다.

            앱 \(Self.appVersion)
            \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
            """
        var url = URLComponents(string: "mailto:\(Self.address)")
        url?.queryItems = [URLQueryItem(name: "subject", value: "뭐라고 — 의견"),
                           URLQueryItem(name: "body", value: 본문)]
        // `mailto` 의 물음표 뒤는 공백을 `+` 로 적어도 되지만, 메일 앱은 그것을 글자
        // `+` 로 읽는다. 본문이 `+` 투성이가 되므로 퍼센트로 적는다.
        let 주소 = url?.url.map { URL(string: $0.absoluteString.replacingOccurrences(of: "+", with: "%20")) ?? $0 }
        guard let 주소 else { return }
        openURL(주소) { 열렸나 in
            guard !열렸나 else { return }
            UIPasteboard.general.string = Self.address
            copiedAddress = true
        }
    }
}
