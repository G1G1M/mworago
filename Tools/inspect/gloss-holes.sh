#!/bin/sh
# 한국어 뜻이 빈 자리를 **순위 구간별로** 센다.
#
#   ./Tools/inspect/gloss-holes.sh [빈도목록] [순위상한] [색인]
#
# 왜 있느냐: "얼마나 덮였나"를 굽기 로그로는 알 수 없다. 로그는 **이번에 몇 개를
# 구웠는지**만 말하고, 남은 구멍이 어디에 몰려 있는지는 말하지 않는다. 5시간짜리
# 굽기가 1~3만 등을 열다섯 개밖에 못 채우고 있던 것을 그래서 오래 못 봤다.
#
# **빈도 목록이 곧 과녁이다.** 앱이 싣는 것으로 재야 앱의 구멍이 나온다 —
# JPDB 로 3만 등까지 구워 놓고도 앱(JESC) 기준으로는 1,232개가 비어 있었다.
#
# **잣대를 둘 쓴다.** 아래 첫 표는 굽기와 같은 잣대로 센다(빈도 목록의 표기·읽기 쌍).
# 그것만 보면 **굽기가 스스로를 채점하는 꼴**이라, 애초에 대상으로 안 잡힌 것은
# 구멍으로도 안 잡힌다. 실제로 `やめる` 가 그렇게 빠졌다 — 말뭉치는 가나로 적고
# 사전은 `止める` 로 실어 짝이 안 맞았는데, 세는 쪽도 같은 짝으로 세니 98.9% 가 나왔다.
# 그래서 두 번째 표는 **읽기로 닿는 표제항 전부**를 센다. 앱이 실제로 하는 일이 그것이다
# — 소리로 찾아 그 읽기를 가진 표제항을 늘어놓는다. 두 숫자가 벌어지는 만큼이
# 지금 안 보이는 자리다.
#
# **구운 파일이 아니라 색인을 본다.** 파일에 있는 뜻이 색인에 다 실리는 것은 아니다.
# 굽는 자리에서 `KoreanGloss.tidy` 가 설명문을 한 번 더 걷어내는데, 파일만 세면
# 그렇게 빠진 것들이 덮인 것으로 잡힌다. 앱이 읽는 것은 색인이다.
set -e
cd "$(dirname "$0")/../.."

FREQ=${1:-MworagoApp/Resources/jesc_freq.tsv}
MAXRANK=${2:-100000}
INDEX=${3:-Tools/data/mworago-dict.db}
BINARY=.build/arm64-apple-macosx/debug/Translator
TARGETS=$(mktemp)
trap 'rm -f "$TARGETS"' EXIT

swift build --product Translator > /dev/null
# 대상은 굽기와 **같은 잣대**로 고른다. 여기서 따로 세면 그 수가 굽기의 수와 어긋난다.
"$BINARY" --dry-run --index "$INDEX" \
          --freq "$FREQ" --max-rank "$MAXRANK" --limit 999999 > "$TARGETS" 2>/dev/null

FREQ="$FREQ" TARGETS="$TARGETS" INDEX="$INDEX" python3 - <<'PY'
import os, sqlite3, collections

def rows(path):
    out = []
    for line in open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        c = line.rstrip("\n").split("\t")
        if len(c) >= 2:
            out.append((c[0], c[1]))
    return out

# 색인의 한 칸은 `글자\x1f우선순위\x1f드묾` 이고 여러 칸이 \x1e 로 이어진다.
def forms(field, drop_rare=False):
    out = []
    for chunk in (field or "").split("\x1e"):
        if not chunk:
            continue
        parts = chunk.split("\x1f")
        # **드문 표기(`rK`·`sK`)는 그 낱말의 표기가 아니다.** 為る(する)가 그렇다 —
        # 앱도 굽는 쪽도 그것을 빼고 보므로(`usableWritings`), 여기서도 빼야
        # `する` 같은 최상위 빈도 낱말이 없는 구멍으로 잡히지 않는다.
        if drop_rare and len(parts) > 2 and parts[2] == "1":
            continue
        out.append(parts[0])
    return out

# 뜻이 실린 (표기, 읽기) 짝을 색인에서 그대로 읽는다.
have = set()
db = sqlite3.connect(os.environ["INDEX"])
for writings, readings, korean in db.execute(
        "select writings, readings, korean from entries"
        " where korean is not null and korean != ''"):
    reads = forms(readings)
    # 표기가 없는 낱말은 읽기가 곧 표기다 — 굽는 쪽이 고르는 잣대와 같게 맞춘다.
    for writing in forms(writings, drop_rare=True) or reads:
        for reading in reads:
            have.add((writing, reading))

targets = rows(os.environ["TARGETS"])

# 순위는 빈도 목록에서 온다. 두 목록 다 `표기 · 읽기 · 순위 · 횟수` 차례다
# (JPDB 는 쉼표, JESC 는 탭). 머리줄은 순위 자리가 숫자가 아니라 저절로 걸러진다.
rank = {}
for line in open(os.environ["FREQ"], encoding="utf-8"):
    c = line.rstrip("\n").replace(",", "\t").split("\t")
    if len(c) >= 3:
        try:
            rank[(c[0], c[1])] = int(c[2])
        except ValueError:
            continue

BANDS = [(1, 1000), (1000, 5000), (5000, 10000), (10000, 30000), (30000, float("inf"))]
counts = collections.Counter()
holes = []
for key in targets:
    r = rank.get(key, 10**9)   # 목록에 없으면 맨 아래 칸으로
    band = next(b for b in BANDS if b[0] <= r < b[1])
    counts[(band, "대상")] += 1
    if key not in have:
        counts[(band, "구멍")] += 1
        holes.append((r, key))

print(f"{'순위 구간':>14}  {'대상':>6}  {'구멍':>6}  {'덮은 비율':>8}")
print("─" * 44)
total = hole_total = 0
for band in BANDS:
    t = counts[(band, "대상")]
    h = counts[(band, "구멍")]
    if not t:
        continue
    total += t
    hole_total += h
    label = f"{band[0]:,}~{band[1]:,}" if band[1] != float("inf") else f"{band[0]:,}~"
    print(f"{label:>14}  {t:6,}  {h:6,}  {100 * (t - h) / t:7.1f}%")
print("─" * 44)
print(f"{'합계':>14}  {total:6,}  {hole_total:6,}  {100 * (total - hole_total) / max(total, 1):7.1f}%")

if holes:
    holes.sort()
    print("\n가장 흔한 구멍 스물")
    for r, (w, rd) in holes[:20]:
        print(f"  {r:>6}위  {w}({rd})")

# ── 두 번째 잣대: 읽기로 닿는 표제항 ──────────────────────────────
#
# 앱은 소리로 찾는다. 조회 키 하나에 표제항이 여럿 걸리고, 카드는 1위를 보이며
# 나머지는 `다른 뜻 N` 에 넣는다. 그러니 **그 읽기로 나올 수 있는 표제항 전부**가
# 사용자가 만날 수 있는 집합이다. 위 표가 세지 않는 쪽이 여기서 잡힌다.
#
# 조회 키(`readings.reading`)는 이미 접혀 있으므로 접는 규칙을 여기서 다시 쓰지 않는다.
# 대상의 표제항을 먼저 찾고, 그 표제항이 달고 있는 키로 되짚어 넓힌다.

entry_of = {}          # (표기, 읽기) → 표제항 id
keys_of = {}           # 표제항 id → 조회 키들
korean_of = {}         # 표제항 id → 한국어 뜻
for eid, writings, readings, korean in db.execute(
        "select id, writings, readings, korean from entries"):
    korean_of[eid] = korean or ""
    reads = forms(readings)
    for writing in forms(writings, drop_rare=True) or reads:
        for reading in reads:
            entry_of.setdefault((writing, reading), eid)
for key, eid in db.execute("select reading, entry_id from readings"):
    keys_of.setdefault(eid, set()).add(key)

by_key = {}            # 조회 키 → 표제항 id 들
for key, eid in db.execute("select reading, entry_id from readings"):
    by_key.setdefault(key, set()).add(eid)

counts2 = collections.Counter()
seen_entry = {}        # 표제항 id → 가장 높은 순위 (한 번만 센다)
for key in targets:
    eid = entry_of.get(key)
    if eid is None:
        continue
    r = rank.get(key, 10**9)
    for k in keys_of.get(eid, ()):
        for reachable in by_key.get(k, ()):
            if seen_entry.get(reachable, 10**9) > r:
                seen_entry[reachable] = r

for eid, r in seen_entry.items():
    band = next(b for b in BANDS if b[0] <= r < b[1])
    counts2[(band, "대상")] += 1
    if not korean_of.get(eid):
        counts2[(band, "구멍")] += 1

print()
print("읽기로 닿는 표제항 기준 — **앱이 늘어놓을 수 있는 것 전부**")
print(f"{'순위 구간':>14}  {'대상':>6}  {'구멍':>6}  {'덮은 비율':>8}")
print("─" * 44)
total2 = hole2 = 0
for band in BANDS:
    t = counts2[(band, "대상")]
    h = counts2[(band, "구멍")]
    if not t:
        continue
    total2 += t
    hole2 += h
    label = f"{band[0]:,}~{band[1]:,}" if band[1] != float("inf") else f"{band[0]:,}~"
    print(f"{label:>14}  {t:6,}  {h:6,}  {100 * (t - h) / t:7.1f}%")
print("─" * 44)
print(f"{'합계':>14}  {total2:6,}  {hole2:6,}  {100 * (total2 - hole2) / max(total2, 1):7.1f}%")
print()
print(f"두 잣대의 차이: 대상 {total2 - total:+,}개 · 구멍 {hole2 - hole_total:+,}개")
print("이 차이가 **굽기와 같은 잣대로는 안 보이는 자리**다.")
print()
print("두 숫자를 그대로 견주지 말 것. 위는 굽기의 진도이고, 아래는 화면에 나올 수")
print("있는 것 전부다 — 흔한 읽기일수록 동음이의어 꼬리가 길어(`は` 11개 · `し` 40개)")
print("아래 표의 상위 구간이 낮게 나온다. 그 꼬리는 대개 카드의 `다른 뜻 N` 에 들어가고")
print("1위로는 잘 안 올라온다. **아래 표는 바닥값이지 사용자가 겪는 값이 아니다.**")
print("1위만 세려면 순위를 매겨 봐야 하므로 이 도구가 아니라 측정기가 할 일이다.")
PY