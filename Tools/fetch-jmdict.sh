#!/bin/sh
# JMdict(일영 사전) 원본을 내려받는다. EDRDG 배포, CC BY-SA 4.0.
set -e
cd "$(dirname "$0")/.."
curl -L -o Data/JMdict_e.gz http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz
gunzip -kf Data/JMdict_e.gz
ls -lh Data/JMdict_e
