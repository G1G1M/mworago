# 뭐라고

![정확도](https://img.shields.io/badge/%EC%A0%95%ED%99%95%EB%8F%84-137%2F150%20%2891%25%29-171717?style=flat-square)
![3위 안](https://img.shields.io/badge/3%EC%9C%84%20%EC%95%88-147%2F150%20%2898%25%29-171717?style=flat-square)
![테스트](https://img.shields.io/badge/%ED%85%8C%EC%8A%A4%ED%8A%B8-329%EA%B0%9C-4a4a4a?style=flat-square)
![플랫폼](https://img.shields.io/badge/iPadOS%20%C2%B7%20iOS-18%2B-b0b0b0?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-6.2-b0b0b0?style=flat-square)
![JMdict](https://img.shields.io/badge/JMdict-CC%20BY--SA%204.0-b0b0b0?style=flat-square)

한글로 들리는 대로 치면 원래 일본어를 찾아주는 iPadOS 앱.

애니를 보다 걸린 대사를 한글로 검색하면 원문이 나오고, 그게 모여 그 화의 교재가 되고,
쉐도잉해서 결국 자막 없이 알아듣게 되는 것을 목표로 한다.

기존 한글-일본어 변환기는 "다이죠부"에 `ダイジョブ`를 뱉는다.
`大丈夫`를 찾아주는 도구가 없어서 만든다.

## 화면

<table>
  <tr>
    <td align="center" width="20%"><img src="docs/screenshots/iphone-1-찾기.png" alt="찾은 순간" width="100%"></td>
    <td align="center" width="20%"><img src="docs/screenshots/iphone-2-문장.png" alt="문장 뜻까지" width="100%"></td>
    <td align="center" width="20%"><img src="docs/screenshots/iphone-3-책장.png" alt="책장" width="100%"></td>
    <td align="center" width="20%"><img src="docs/screenshots/iphone-4-연습.png" alt="연습 카드" width="100%"></td>
    <td align="center" width="20%"><img src="docs/screenshots/iphone-5-글자.png" alt="오십음도" width="100%"></td>
  </tr>
  <tr>
    <td align="center"><b>찾기</b><br><sub>들린 대로 치면<br>원문이 나온다</sub></td>
    <td align="center"><b>문장</b><br><sub>조각으로 갈라 주고<br>문장 뜻까지</sub></td>
    <td align="center"><b>책장</b><br><sub>담은 것이<br>교재가 된다</sub></td>
    <td align="center"><b>연습</b><br><sub>가나를 보고<br>뜻을 떠올린다</sub></td>
    <td align="center"><b>글자</b><br><sub>가나를 못 읽어도<br>괜찮다</sub></td>
  </tr>
</table>

## 무엇이 되는가

한글로 들리는 대로 치면 원문이 나온다. **띄어 쓰지 않아도 되고**, 활용형은 사전형으로
되돌려 찾으며, 가나를 몰라도 된다.

```
아타마가이타이  →  頭が痛い        あたまがいたい
이타이야메로    →  痛いやめろ      痛い · 止める[명령형]
다이죠부데스카  →  大丈夫ですか    大丈夫 · です · か
```

찾은 것은 담아 두면 그대로 교재가 되고(책장), 가나를 보고 뜻을 떠올리는 연습으로
이어진다. 오십음도는 막혔을 때 돌아올 자리다.

**돌아가는 것을 숫자로 적어 둔다.** 케이스 150개 기준 1위가 정답인 것 137개,
3위 안 147개. 소리대로 쳤을 때 맨 위 카드에 한국어 뜻이 뜨는 비율 98.3%.
케이스와 잣대는 손으로 정하지 않는다 — 빈도 목록이 낱말을 고르고,
문장 분절의 정답은 Tanaka Corpus 에서 온다.

## 왜 어려운가

한글 음차는 일본어의 정보를 다섯 가지 잃는다.

| 잃는 것 | 예 | 문제 |
|---|---|---|
| 장음 | だいじょ**う**ぶ → "다이죠부" | う가 증발 |
| 외래어 장음 | コ**ー**ト → "코트" | ー가 증발. 늘인 자리를 한글은 아예 적지 못한다 |
| 탁음/청음 | だ / た → "다" 또는 "타" | 한국어 어두에 유성음이 없음 |
| 촉음 | い**っ**しょ → "잇쇼" | 받침 ㅅ으로 뭉개짐 |
| 발음 ん | せ**ん**ぱい → "센빠이" | 받침 ㄴ·ㅁ·ㅇ 아무거나 |
| つ | つ → "츠" / "쓰" / "스" | 셋 다 쓰인다 |

가나에서 한글로 가는 길은 답이 하나지만, 반대 방향은 답이 여럿이다.
그래서 정답 하나를 고르지 않고 후보를 모두 펼친 뒤 사전으로 걸러낸다.

늘인 소리는 일본어 쪽에서도 갈린다 — `コート`는 장음부호로, `とうきょう`는 `う`로,
`おおきい`는 `お`로 늘인다. 후보와 사전이 서로 다른 표기를 골라 어긋나지 않도록,
**사전을 찾을 때 쓰는 키는 늘인 자리를 장음부호 하나로 접는다**(`KanaTable.lookupKey`).
늘이지 않은 낱말까지 뭉개지는 않는다 — `こと`(일)와 `コート`(외투)는 끝까지 다른 키다.

## 구성

**층을 폴더가 아니라 SPM 타깃으로 나눈다.** 폴더로만 나누면 "무엇이 무엇을 불러도
되는가"가 문서에 남고 그 문서는 언젠가 어긋난다. 타깃으로 나누면 도메인에서 SQLite 를
부르는 순간 빌드가 멎는다.

의존은 한 방향으로만 흐른다 — `Domain ← UseCases ← Infra`. 앱과 측정 도구가 같은
코드를 쓰므로, 도구로 잰 숫자가 그대로 앱의 숫자다.

### 무엇으로 만들었나

| | |
|---|---|
| 언어 · 화면 | Swift 6.2 · SwiftUI (iPadOS · iOS 18+) |
| 사전 | JMdict 를 SQLite 색인 하나로 미리 구워 싣는다 |
| 빈도 | 자막 말뭉치(JESC)에서 직접 센 목록 |
| 문장 뜻 | Apple `Translation` — 기기 안에서 돈다 |
| 소리 | `AVSpeechSynthesizer` |
| 빌드 | SwiftPM(코어) · XcodeGen(앱) |
| 네트워크 | **없다.** 앱이 바깥과 통신하지 않는다 |

### 코어 — 세 층

```
Sources/
  MworagoDomain/      엔티티와 포트. Foundation 밖을 모른다
    Kana/               한글 ↔ 가나, 일본어 읽기
    Words/              표제항 · 담은 낱말 · 빈도 · 품사 · 뜻
    Ports/              바깥에 무엇을 요구하는지

  MworagoUseCases/    찾고 나누고 줄 세우는 일. 도메인만 안다
    Search/             한 줄을 받아 낱말 후보까지
    Sentence/           조각을 도로 문장으로, 그리고 그 뜻

  MworagoInfra/       바깥과 닿는 것들
    Dictionary/         구운 색인과 빈도를 여는 일
    Storage/            기기에 남는 것 — 담은 낱말 · 설정

  MworagoCore/        셋을 한 이름으로 내보내는 우산
```

### 앱

```
MworagoApp/
  App/                조립이 시작되는 자리
  Composition/        무엇을 세워 어디로 내려보낼지
  Store/              화면이 지켜보는 것들
  Views/              화면. 탭이 곧 폴더다
    Root/               탭 다섯과 그 앞의 두 장 — 스플래시 · 온보딩
    Find/               찾기
    Library/            책장
    Practice/           연습
    Kana/               가나표
    Settings/           설정
    Shared/             화면들이 나눠 쓰는 것 — 색 · 글자 크기 · 판 · 소리
```

### 시험과 도구

```
MworagoTests/         테스트 329개. 코어와 같은 층으로 나눈다
Tools/                앱에 실리지 않는다
  fetch/                사전 · 빈도 · 글꼴 · 예문 내려받기
  bake/                 받은 것을 앱이 실을 모양으로 굽기
```

## 실행

```sh
swift test                  # 테스트 329개
./Tools/fetch/fetch-jmdict.sh     # 사전 내려받기, 약 10MB
swift run SpikeRunner       # 측정
```

앱은 자료를 먼저 구워야 한다. 색인(40MB)과 빈도 목록은 원본에서 만들어 내는 것이라
레포에 두지 않는다.

```sh
./Tools/bake/setup-app-resources.sh   # 색인·빈도·폰트를 굽고 번들 폴더에 넣는다
xcodegen generate
xcodebuild -project Mworago.xcodeproj -scheme Mworago \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build
```

시뮬레이터에 한글을 타이핑하지 않고 화면을 확인하려고 실행 인자를 두었다.
손으로 두드릴 수 없는 자리(시트·모달)를 눈으로 보려는 것이다.

```sh
xcrun simctl launch <device> com.g1g1e.Mworago --query=다이죠부야쿠소쿠
#   찾기
#   --query=<검색어>              검색 결과 화면
#   --select=<N>                  N 번째 조각을 고른 상태
#   --collect                     검색 결과를 전부 담은 채로
#   --expanded                    카드의 `다른 뜻 N` 을 펴 둔 채로
#   --collecting                  담을 곳을 묻는 판을 펼친 채로
#   --naming                      그 판에서 새 이름을 받는 칸까지 펼친 채로
#   --guide                       입력 도움말
#   --credits                     도움말 안의 "이 앱이 쓰는 자료"까지
#   책장
#   --tab=library|practice|kana|settings   그 탭을 연 채로
#   --folder[=이름]               책장의 그 묶음에 들어간 채로
#   --detail                      첫 낱말의 상세를 펼친 채로
#   --new-folder                  책장의 "새 묶음" 판을 펼친 채로
#   --menu                        묶음 화면의 할 일 목록을 펼친 채로
#   --picking                     묶음 화면에서 낱말을 전부 고른 채로
#   --moving                      그 위에 "어디로 옮길까요" 판까지
#   --list-picking                책장 `모두` 목록에서 낱말을 전부 고른 채로
#   --list-moving                 그 위에 "어디로 옮길까요" 판까지
#   연습·가나
#   --revealed                    연습 카드를 뒤집은 채로
#   --quiz                        가나 탭을 `익히기` 쪽으로 연 채로
#   --kana=<글자>                 그 글자의 상세를 펼친 채로
#   앞의 두 장
#   --no-splash                   스플래시 건너뛰기
#   --onboarding                  온보딩을 봤는지와 무관하게 다시 띄운다
#   --onboarding-page=<N>         온보딩의 N 번째 장(0부터, 탭 차례대로 다섯 장)
#   --onboarded                   온보딩을 건너뛴다(적어 두지는 않는다).
#                                 새 시뮬레이터는 무엇을 띄우든 온보딩이 먼저 뜬다
```

**이름이 앞에서 겹쳐도 켜지지 않는다** — `--picking`(묶음 화면)과
`--list-picking`(책장 목록)은 한 화면에 겹쳐 설 수 있어 이름을 나눠 두었다.
인자를 읽는 자리는 `LaunchOptions` 하나다.

찍은 화면은 **눈으로 읽지 말고 재는 편이 낫다.** 2420px 짜리 스크린샷이 줄어들어
들어오면 위쪽 끝의 글자가 아래쪽 끝에 한 번 더 있는 것처럼 읽힌다 — "건너뛰기가
위아래로 두 번 그려진다"는 보고가 그렇게 났고, 재현하러 들어가서 같은 착시를 두 번 더
했다. 글자가 있는 가로줄만 뽑아 보면 몇 벌인지 다툴 일이 없다.

```sh
swift Tools/inspect/ink-rows.swift shot.png 1150 1668   # x 범위를 좁혀 오른쪽 끝만
```

**색인 스키마를 바꾸면 `schemaVersion` 을 올리고 다시 구울 것.** 안 그러면 앱이
"색인이 낡았다(판 2, 필요한 판 3)"고 알려 준다 — 예전에는 `no such column` 으로 죽었다.

## 쓰는 자료

전부 `Tools/fetch/` 의 스크립트로 받아 쓰고 레포에 넣지 않는다.
**CC BY-SA 는 재배포 시 출처 표시가 의무**라 앱 설정 화면에도 명시한다
(설정 › 이 앱이 쓰는 자료). 아래 표에서 **싣는다**로 적힌 것만 앱 안에 들어간다 —
나머지는 만드는 쪽 기계에서만 쓰인다.

| 무엇 | 어디에 쓰나 | 앱에 | 라이선스 |
|---|---|---|---|
| [JMdict](https://www.edrdg.org/jmdict/j_jmdict.html) | 사전 본체. 표제항 218,665 · 읽기 265,528 | 싣는다 | EDRDG · CC BY-SA 4.0 |
| [kanjidic2](https://www.edrdg.org/wiki/index.php/KANJIDIC_Project) | 한자의 한국 독음 6,293자 | 싣는다 | EDRDG · CC BY-SA 4.0 |
| [JESC](https://nlp.stanford.edu/projects/jesc/) | 낱말이 얼마나 흔한지. 자막 279만 문장 | 싣는다 | Stanford · CC BY-SA 4.0 |
| Zen Maru Gothic · 고운돋움 | 글꼴 | 싣는다 | SIL OFL 1.1 |
| [Tanaka Corpus](https://www.edrdg.org/wiki/index.php/Tanaka_Corpus) | 문장 분절의 정답지 | 측정만 | EDRDG · CC BY-SA 4.0 |
| JPDB v2.2 | 측정 기준선 | 측정만 | 재배포 조건 불분명 |

**빈도표는 JESC 로 갈았다.** 한때 JPDB 로 재고 그 숫자를 뱃지에 걸어 두었는데,
재배포 조건이 불분명해 앱에 실을 수가 없다. 갈아 보니 **낱말 검색은 5건 차이**
(142 → 137/150)인데 **분절이 훨씬 민감하다** — 검색은 하나만 맞히면 되지만 분절은
문장의 모든 낱말을 찾아야 하기 때문이다. **앱 성적을 볼 때는 배포판이 싣는 것으로
재야 한다**(`--freq MworagoApp/Resources/jesc_freq.tsv`). 기준선을 하나만 쥐고
있으면 이 손해가 눈에 안 보인다.

한때 이 자리에 [Jiten](https://jiten.moe/frequency-dictionaries)(애니 3,709편 기준,
CC BY-SA 4.0)을 "도입 예정"으로 적어 두었는데 **도입하지 않았다.** JESC 로 조건이
풀려서 옮길 이유가 없어졌다. 애니 도메인에 더 가까운 빈도가 필요해지면 그때 다시 본다.

### 뜻을 굽는 모델

낱말 뜻은 **모델이 만든 것**이라 그 모델의 라이선스가 배포를 막을 수 있다.

처음에 **EXAONE 3.5 7.8B** 로 구웠는데 `EXAONE AI Model License Agreement 1.1 - NC`
라, **출력물까지 조건이 붙어 앱스토어에 낼 수 없다.** 재배포가 자유로운 쪽으로
다시 굽는다 — **Qwen3(Apache 2.0)**. 고르기 전에 사람이 손으로 적은 정답지로 재 보고
골랐다.

손으로 적은 표는
사람이 쓴 것이라 이 문제와 무관하고, 색인을 구울 때 기계 뜻 위에 덮어쓴다.

## 라이선스

**코드는 아직 미정이다** — 저장소에 `LICENSE` 파일이 없다. 미국 저작권법의 기본값이
적용되므로, 지금 이 코드는 **읽는 것 말고 허락된 것이 없다.** 앱을 내면서 정한다.

**자료는 다르다.** 싣는 자료가 전부 CC BY-SA 4.0 이고 그 조건은 저작자 표시와
동일조건변경허락이다. 구운 색인(`mworago-dict.db`)과 빈도 목록은 그 자료의 2차적
저작물이라 같은 조건으로 내놓아야 한다.

**그래서 파일 자체를 릴리스에 올린다** —
[data-2026-09-08](https://github.com/G1G1M/mworago/releases/latest) 에
`mworago-dict.db`(39.7MB)와 `jesc_freq.tsv`(2.2MB)가 CC BY-SA 4.0 으로 있다.
앱 설정의 「이 앱이 쓰는 자료」도 그 자리를 가리킨다. 색인을 다시 구우면 새 릴리스를
올리므로 주소는 `releases/latest` 로 둔다.

> 한동안은 저장소를 가리키고 "색인을 만드는 도구가 여기 있다"고 적었다(색인이 40MB
> 라 `.gitignore` 가 뺀다). 그 길도 조건은 채우지만, **다시 만들 수 있는 길과 그
> 물건 자체는 다르다.** 받는 쪽이 도구를 돌려야 손에 넣는 것보다 파일을 그대로 받는
> 편이 낫다. 도구는 그대로 있으니 직접 구워도 같은 것이 나온다.

**앱 코드는 2차적 저작물이 아니다** — 자료를 읽어 쓸 뿐인 단순 결합이라 공개할
의무가 없다. 지금 이 저장소가 열려 있는 것은 의무가 아니라 고른 것이다.
