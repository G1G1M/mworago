#!/bin/sh
# 도메인(애니·드라마·라노벨) 빈도 목록을 내려받는다.
#
# JMdict의 빈도 태그는 신문 말뭉치 기준이라 애니 대사와 어긋난다.
#   遺体(いたい)  JMdict 67점 · 애니 4680위
#   痛い(いたい)  JMdict 54점 · 애니  592위
#
# 지금 쓰는 것은 JPDB 배포본이다. 검증에는 충분하지만 **재배포 조건이 불분명하다.**
# 앱에 실을 때는 CC BY-SA 4.0으로 배포되는 Jiten 쪽으로 바꿔야 한다.
#   https://jiten.moe/frequency-dictionaries  (애니 3,709편 기준, CSV)
set -e
cd "$(dirname "$0")/../.."
curl -L -o Tools/data/jpdb_freq.csv \
  "https://raw.githubusercontent.com/Kuuuube/yomitan-dictionaries/main/data/jpdb_v2.2_freq_list_2024-10-13.csv"
ls -lh Tools/data/jpdb_freq.csv
