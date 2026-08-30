#!/bin/sh
# 앱이 실을 사전 색인을 굽는다.
#
# JMdict XML 을 그대로 쓰면 앱을 열 때마다 60MB 를 파싱하느라 3초를 쓰고
# 표제항 26.5만 개가 통째로 메모리에 올라간다. 색인은 열 때 아무것도 읽지 않고
# 검색할 때 필요한 행만 꺼낸다.
#
#   XML 파싱   3.1초  →  색인 열기  0.001초
set -e
cd "$(dirname "$0")/.."
[ -f Tools/data/JMdict_e ] || ./Tools/fetch-jmdict.sh
swift run SpikeRunner --build-index Tools/data/mworago-dict.db
