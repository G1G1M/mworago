#!/bin/sh
# JMdict(일영 사전) 원본을 내려받는다. EDRDG 배포, CC BY-SA 4.0.
# 받은 파일은 Tools/data/ 에 둔다 — 앱에 실리는 것이 아니라 측정에 쓰는 원본이다.
set -e
cd "$(dirname "$0")/.."
curl -L -o Tools/data/JMdict_e.gz http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz
gunzip -kf Tools/data/JMdict_e.gz
ls -lh Tools/data/JMdict_e
