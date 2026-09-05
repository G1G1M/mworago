#!/usr/bin/env python3
# 후보 모델이 구운 뜻을 **사람이 적어 둔 정답지**에 대고 센다.
#
#   ./Tools/inspect/score-gloss.py [Tools/data/bench/*.tsv]
#
# 무엇을 재느냐가 둘로 갈린다.
#
#   꼴    화면에 그대로 실을 수 있는 모양인가. 한국어만 쓰였는가, 길이가 맞는가,
#         설명문이 아닌가. 이것은 기계가 정확히 잴 수 있다.
#   뜻    맞는 뜻인가. 이것은 **글자 대조로는 못 잰다** — `노리다` 와 `겨누다` 는
#         둘 다 맞지만 글자가 다르고, 여기서는 틀린 것으로 세어진다.
#
# 그래서 뜻 쪽 숫자는 **바닥값**이다. 실제 정답률은 이보다 높다. 후보끼리 견주는
# 데에는 그대로 쓸 수 있지만(모두 같은 잣대로 손해를 본다), "몇 퍼센트가 맞다"로
# 읽으면 안 된다. 마지막 판단은 `*.review.tsv` 를 사람이 읽어서 한다.
#
# 정답지 둘의 성격이 다르다는 것도 함께 읽어야 한다.
#
#   corrected  EXAONE 이 **틀린 것만** 골라 고친 것이라 EXAONE 자신은 정의상 0점에
#              가깝다. 후보끼리는 공평하지만 EXAONE 과의 비교에는 못 쓴다.
#   guardrail  애플 모델이 거부해 사람이 적은 것. 고른 잣대가 EXAONE 과 무관해
#              **기준선으로 쓸 수 있는 쪽은 이쪽이다.**
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
GOLD = ["corrected-gloss", "guardrail-gloss"]

# 한국어 뜻 자리에 와도 되는 글자. 한자·가나·라틴이 섞이면 화면에 그대로 못 싣는다.
ALLOWED = re.compile(r"^[가-힣0-9\s,·~()\-—…?!.]+$")
# 뜻이 아니라 설명을 적은 것. 사전 자리에 문장이 들어앉은 꼴이다.
EXPLAINING = ("하는 것", "것을", "의미", "라는 뜻", "을 뜻", "를 뜻", "니다", "습니", "이다.")


def read_tsv(path):
    """표기·읽기 → 뜻. 주석과 빈 줄은 건너뛴다."""
    out = {}
    if not os.path.exists(path):
        return out
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            c = line.rstrip("\n").split("\t")
            if len(c) >= 3 and c[2].strip():
                out[(c[0], c[1])] = c[2].strip()
    return out


def meanings(text):
    """쉼표로 나뉜 뜻 갈래. 빈 것은 버린다."""
    return [m.strip() for m in text.split(",") if m.strip()]


def form_ok(text):
    """화면에 그대로 실을 수 있는 꼴인가."""
    if not text:
        return False, "빈 것"
    if not ALLOWED.match(text):
        return False, "한국어가 아닌 글자"
    parts = meanings(text)
    if not parts:
        return False, "빈 것"
    if len(parts) > 3:
        return False, f"갈래가 {len(parts)}개"
    if any(len(p) > 12 for p in parts):
        return False, "열두 자를 넘음"
    if any(mark in text for mark in EXPLAINING):
        return False, "설명문"
    return True, ""


def judge(model_text, gold_text):
    """뜻이 맞는가. 글자 대조라 **맞는데 틀렸다고 세는 일이 있다.**"""
    m, g = meanings(model_text), meanings(gold_text)
    if not m:
        return "빈 것"
    if m[0] in g:
        return "첫뜻"                    # 사람이 적은 갈래와 첫 뜻이 같다
    if any(x in g for x in m):
        return "겹침"                    # 첫 뜻은 아니지만 갈래 하나가 같다
    for x in m:                          # 한쪽이 다른 쪽을 품는다(`가슴` 대 `가슴속`)
        for y in g:
            if len(x) >= 2 and len(y) >= 2 and (x in y or y in x):
                return "부분"
    return "다름"


def main():
    os.chdir(ROOT)
    paths = sys.argv[1:] or sorted(glob.glob("Tools/data/bench/*.tsv"))
    paths = [p for p in paths if not p.endswith(".review.tsv")]
    if not paths:
        sys.exit("잰 것이 없다. 먼저 ./Tools/inspect/bench-gloss.sh <모델> 을 돌린다.")

    golds = {name: read_tsv(f"Tools/data/{name}.tsv") for name in GOLD}
    everything = {}
    for name in GOLD:
        everything.update(golds[name])

    rows = []
    for path in paths:
        model = os.path.basename(path)[: -len(".tsv")]
        baked = read_tsv(path)
        shared = [k for k in everything if k in baked]
        if not shared:
            print(f"{model}: 정답지와 겹치는 것이 없다 — 건너뛴다")
            continue

        counts = {"첫뜻": 0, "겹침": 0, "부분": 0, "다름": 0, "빈 것": 0}
        form_bad = 0
        per_gold = {name: {"n": 0, "hit": 0} for name in GOLD}
        review = []
        for key in sorted(shared):
            got, want = baked[key], everything[key]
            ok, why = form_ok(got)
            if not ok:
                form_bad += 1
            verdict = judge(got, want)
            counts[verdict] += 1
            for name in GOLD:
                if key in golds[name]:
                    per_gold[name]["n"] += 1
                    if verdict in ("첫뜻", "겹침"):
                        per_gold[name]["hit"] += 1
                    break
            review.append((key[0], key[1], want, got, verdict, why))

        n = len(shared)
        hit = counts["첫뜻"] + counts["겹침"]
        rows.append((model, n, n - form_bad, hit, counts, per_gold))

        with open(f"Tools/data/bench/{model}.review.tsv", "w", encoding="utf-8") as f:
            f.write("# 표기\t읽기\t사람이 적은 뜻\t모델이 적은 뜻\t판정\t꼴이 틀린 까닭\n")
            f.write("# 판정 '다름' 이라고 다 틀린 것이 아니다 — 글자만 다른 것이 섞여 있다.\n")
            for r in review:
                f.write("\t".join(r) + "\n")

    print(f"{'모델':<22}{'잰 것':>7}{'쓸 수 있는 꼴':>15}{'뜻 맞음':>10}"
          f"{'  (첫뜻/겹침/부분/다름)':<24}{'corrected':>11}{'guardrail':>11}")
    for model, n, form, hit, c, per in sorted(rows, key=lambda r: -r[3] / max(r[1], 1)):
        def pct(a, b):
            return f"{a}/{b} {a * 100 // max(b, 1)}%"
        print(f"{model:<22}{n:>7}{form * 100 // n:>14}%{hit * 100 // n:>9}%"
              f"  ({c['첫뜻']}/{c['겹침']}/{c['부분']}/{c['다름']})".ljust(24)
              + f"{pct(per['corrected-gloss']['hit'], per['corrected-gloss']['n']):>15}"
              + f"{pct(per['guardrail-gloss']['hit'], per['guardrail-gloss']['n']):>15}")
    print()
    print("뜻 쪽은 글자 대조라 **바닥값**이다. `Tools/data/bench/<모델>.review.tsv` 를")
    print("사람이 읽어야 진짜 수치가 나온다. corrected 는 EXAONE 이 틀린 것만 모은")
    print("편향 표본이라 EXAONE 기준선으로 읽으면 안 된다.")


if __name__ == "__main__":
    main()
