#!/bin/sh
# 후보 모델의 뜻을 **사람이 적어 둔 정답지**로 잰다.
#
#   ./Tools/inspect/bench-gloss.sh <모델> [정답지...]
#
# 정답지는 둘이다. 성격이 달라서 둘 다 있어야 한다.
#
#   corrected-gloss.tsv  EXAONE 이 **틀린 것만** 사람이 고친 것(698개).
#                        어려운 낱말만 모인 편향 표본이고, EXAONE 자신은 정의상
#                        여기서 0점에 가깝다 — 기준선으로 읽지 말 것.
#   guardrail-gloss.tsv  애플 모델이 **거부한 것**을 사람이 적은 것(931개).
#                        고른 잣대가 EXAONE 과 무관해 후보끼리 견주기에 공평하다.
#
# 굽는 자리는 Translator 를 그대로 쓴다. 프롬프트·지시문·온도를 손으로 옮겨 적으면
# 재는 것과 배포판이 구우는 것이 어긋난다([[feedback_measure_on_shipping_baseline]]).
set -e
cd "$(dirname "$0")/../.."

MODEL=$1
[ -n "$MODEL" ] || { echo "쓰는 법: $0 <모델> [정답지...]" >&2; exit 2; }
shift
GOLD=${*:-"Tools/data/corrected-gloss.tsv Tools/data/guardrail-gloss.tsv"}

OUT="Tools/data/bench/$(echo "$MODEL" | tr ':/' '__').tsv"
BINARY=.build/arm64-apple-macosx/debug/Translator

swift build --product Translator > /dev/null

# 정답지의 표기를 모아 쉼표로 잇는다. `--only` 는 표기나 읽기가 걸리면 집는다.
#
# **`LC_ALL=C` 가 있어야 한다.** macOS 기본 로케일의 `sort -u` 는 서로 다른 한자를
# 같은 것으로 보고 지운다 — 표기 1,629개가 1,248개로 줄어 정답지의 4분의 1이
# 조용히 사라졌다([[feedback_macos_sort_locale]]).
ONLY=$(cat $GOLD | grep -v '^#' | cut -f1 | LC_ALL=C sort -u | grep . | tr '\n' ',' | sed 's/,$//')

mkdir -p Tools/data/bench
rm -f "$OUT"
echo "== $MODEL → $OUT"
"$BINARY" --ollama "$MODEL" --only "$ONLY" --out "$OUT" \
          --limit 999999 --max-rank 100000
