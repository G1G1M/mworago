#!/bin/sh
# 한국어 뜻을 교대로 굽는다.
#
# **한 프로세스로 오래 돌리면 안 된다.** 열세 시간 돌던 프로세스는 셋 중 하나를
# 놓쳤는데(36~39%), 같은 구간을 갓 띄운 프로세스로 돌리니 8%만 놓쳤다.
# 놓친 것의 종류도 달랐다 — 오래 돈 쪽에만 `unsupportedLanguageOrLocale` 이 있고,
# 갓 띄운 쪽은 전부 가드레일(성인·폭력어)이라 어차피 못 받아 올 것들이었다.
# 그러니 일정 시간마다 끊고 새로 띄운다.
#
# Translator 는 결과를 한 건씩 파일에 붙이고 다음 실행에서 이미 끝난 것을 건너뛴다.
# 그래서 끊는 것이 안전하고, 다음 교대가 앞 교대의 실패분을 저절로 다시 집는다.
#
#   nohup ./Tools/translate-in-shifts.sh > Tools/data/shifts.log 2>&1 &
set -e
cd "$(dirname "$0")/.."
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH

GLOSS=Tools/data/korean-gloss.tsv
BINARY=.build/arm64-apple-macosx/debug/Translator
# 한 교대의 길이. 짧을수록 성해지지만 사전을 다시 읽는 값(4초)이 자주 든다.
SHIFT=1800
# 한 교대에서 이만큼도 못 건지면 남은 것은 가드레일이다 — 더 돌려도 그대로다.
MIN_GAIN=20

lines() { [ -f "$GLOSS" ] && wc -l < "$GLOSS" | tr -d ' ' || echo 0; }

swift build --product Translator > /dev/null

shift_no=1
while :; do
    before=$(lines)
    "$BINARY" >> Tools/data/translator.log 2>&1 &
    pid=$!

    waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$SHIFT" ]; do
        sleep 10
        waited=$(( waited + 10 ))
    done

    if kill -0 "$pid" 2>/dev/null; then
        # 아직 돌고 있다 — 교대 시간이 다 된 것이다. 끊고 새로 띄운다.
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        finished=no
    else
        # 스스로 끝났다 — 남은 것이 없거나(다 끝났다) 모델을 못 쓰는 상태다.
        wait "$pid" 2>/dev/null || true
        finished=yes
    fi

    gain=$(( $(lines) - before ))
    echo "${shift_no}교대 · ${gain}개 · 누계 $(lines)줄 · $(date '+%H:%M')"

    if [ "$finished" = yes ] && [ "$gain" -lt "$MIN_GAIN" ]; then
        echo "더 건질 것이 없다 · $(date '+%H:%M')"
        break
    fi
    shift_no=$(( shift_no + 1 ))
done
