#!/bin/sh
# 번역이 끝나면 색인을 굽고 앱 리소스까지 갱신한다.
#
# 한국어 뜻 굽기는 2만 건에 열 시간쯤 걸린다. 끝나기를 사람이 지켜보고 있을 일이
# 아니라서, 끝나는 것을 기다렸다가 다음 단계를 이어 준다 —
# 회수 → 색인 굽기 → 앱 리소스 복사 → (앱 빌드는 사람이 한다, 시뮬레이터를 고르는 일이라).
#
#   nohup ./Tools/bake/bake-when-translated.sh > Tools/data/bake.log 2>&1 &
#
# 번역이 이미 끝나 있으면 곧바로 이어서 한다.
set -e
cd "$(dirname "$0")/../.."
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH

GLOSS=Tools/data/korean-gloss.tsv
# 다 구우면 만 단위다. 이보다 적으면 끝난 것이 아니라 무언가 어긋난 것이다.
MINIMUM=5000

lines() { [ -f "$GLOSS" ] && wc -l < "$GLOSS" | tr -d ' ' || echo 0; }

# 프로세스가 안 보이는 것만으로 끝났다고 보면 안 된다 — 실제로 그렇게 한 번 틀렸다.
# 결과를 버리고 처음부터 다시 굽는 찰나에 프로세스가 잠깐 사라졌고, 그 틈에
# 이 스크립트가 빠져나가 **뜻 0개짜리 색인**을 앱에 넣었다.
# 그래서 두 가지를 함께 본다: 프로세스가 없고, 결과 파일도 더는 자라지 않을 것.
while :; do
    if pgrep -f "debug/Translator" > /dev/null 2>&1; then
        sleep 60
        continue
    fi
    before=$(lines)
    sleep 90
    if pgrep -f "debug/Translator" > /dev/null 2>&1; then continue; fi
    [ "$(lines)" = "$before" ] && break
done

echo "번역 멈춤 · $(lines)줄 · $(date '+%H:%M')"

count=$(lines)
# 적게 나왔으면 굽지 않는다. 쓸 만한 색인이 이미 앱에 들어 있을 수 있는데,
# 그것을 빈 것으로 덮는 편이 아무것도 안 하는 것보다 나쁘다.
if [ "$count" -lt "$MINIMUM" ]; then
    echo "한국어 뜻이 ${count}줄뿐이다(최소 ${MINIMUM}). 굽지 않고 멈춘다."
    exit 1
fi

# **굽기 전에 찌꺼기를 걷는다.** 모델이 프롬프트의 보기를 따라 하느라
# "후보 → 고른 것" 을 통째로 뱉는 일이 있다(31,149줄에서 576건이었다).
# 이 걸음이 빠져 있어 그것들이 그대로 앱에 들어갈 뻔했다.
# 살릴 수 없는 것은 `korean-gloss.redo.tsv` 로 빠지고, 다음 굽기가 다시 집는다.
python3 Tools/bake/clean-gloss.py Tools/data/korean-gloss.tsv \
        Tools/data/korean-gloss.clean.tsv Tools/data/korean-gloss.redo.tsv
mv Tools/data/korean-gloss.clean.tsv Tools/data/korean-gloss.tsv

./Tools/bake/build-index.sh
cp Tools/data/mworago-dict.db MworagoApp/Resources/
echo "색인 갱신 완료 · ${count}줄 · $(date '+%H:%M')"
echo "남은 것: xcodegen generate && xcodebuild ... build"
