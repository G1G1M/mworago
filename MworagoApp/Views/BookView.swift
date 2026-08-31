import SwiftUI
import MworagoCore

/// 도감 — 모은 낱말이 **그날 본 것**으로 묶인다.
///
/// 기획은 "화별 교재"인데 앱은 사용자가 어느 화를 보다 걸렸는지 모른다.
/// 그러나 애니 한 화를 보면서 찾은 것들은 같은 날 모이므로, 날짜가 사실상 그 화다.
/// **모르는 것을 지어내는 대신 아는 것으로 묶는다.**
struct BookView: View {
    let collection: CollectionStore

    private static let contentWidth: CGFloat = 640

    private var days: [CollectedWord.Day] { CollectedWord.byDay(collection.words) }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if days.isEmpty { empty } else { list }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                ForEach(days) { day in
                    dayBlock(day)
                    Divider().overlay(Theme.grey3)
                }
            }
            .frame(maxWidth: Self.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("도감")
                .font(Theme.korean(24, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("\(days.count)일")
                .font(Theme.korean(15))
                .foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    /// 하루치.
    ///
    /// 그날의 낱말을 가나로만 늘어놓는다. 뜻까지 펼치면 모은 것 화면과 같은 것이 되고,
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
            }
            FlowRow(lineSpacing: 8) {
                ForEach(day.words) { word in
                    Text(word.reading)
                        .font(Theme.japanese(19))
                        .foregroundStyle(Theme.grey1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.grey4, in: Capsule())
                        .padding(.trailing, 8)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("아직 교재가 없어요")
                .font(Theme.korean(22, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("찾은 낱말을 담으면 그날 본 것끼리 묶여 여기 쌓입니다.")
                .font(Theme.korean(15))
                .foregroundStyle(Theme.grey2)
            Text("애니 한 화를 보며 찾은 것들은 같은 날 모이니까요.")
                .font(Theme.korean(13))
                .foregroundStyle(Theme.grey3)
        }
        .frame(maxWidth: 460, alignment: .leading)
        .padding(.horizontal, 28)
    }
}
