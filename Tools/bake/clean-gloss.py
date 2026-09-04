# -*- coding: utf-8 -*-
"""굽힌 한국어 뜻에서 모델이 흘린 사고 과정을 걷어낸다.

    python3 Tools/bake/clean-gloss.py <구운파일> <정리본> <다시구울목록>

모델이 프롬프트의 보기(`... → 약속`)를 따라 하느라 "후보 → 고른 것" 을 통째로
뱉는 일이 있다. 마지막 화살표 뒤가 답이므로 그것만 남긴다. 품사 나열(`· 명사 ·`)과
마크다운 강조(`**그**`)도 같은 까닭으로 걷어낸다.

살릴 수 없는 것 — 한글이 없거나, 가나·한자가 남았거나, 옮기다 만 영어가 섞였거나,
괄호가 안 닫힌 채 잘린 것 — 은 따로 모아 다시 굽게 한다.
"""
import re, sys

SRC  = sys.argv[1] if len(sys.argv) > 1 else "Tools/data/korean-gloss-exaone.tsv"
OUT  = sys.argv[2] if len(sys.argv) > 2 else "Tools/data/korean-gloss-exaone.clean.tsv"
REDO = sys.argv[3] if len(sys.argv) > 3 else "Tools/data/korean-gloss-exaone.redo.tsv"

HANGUL=re.compile(r"[가-힣]"); KANA=re.compile(r"[぀-ゟ゠-ヿ]"); HAN=re.compile(r"[一-鿿]")
POS=("명사","동사","형용사","형용동사","부사","감탄사","조사","접속사","대명사","관용구","접미사","접두사")

# 뜻이 아니라 **모델이 하는 말**. 이것이 남아 있으면 뜻으로 못 쓴다.
CHATTER=re.compile(r"습니다|합니다|다음과 같|문맥|번역|해석|경우|주의|권장|용어|표현은|의미할")
# 한 뜻의 길이 상한. 이보다 길면 뜻이 아니라 설명이다.
MEANING=12
# 뜻 자리 전체의 길이 상한. 카드 한 줄에 들어가야 한다.
GLOSS=20

def clean(head, gloss):
    g=gloss.strip()
    # 1) 모델이 "후보들 → 고른 것" 으로 적은 경우: 마지막 화살표 뒤가 답이다.
    #    **비어 있으면 그 앞이 답이다.** 화살표를 찍어 놓고 아무것도 안 적는 일이 잦은데
    #    (`색인 →` · `더구나, 하물며 →`), 뒤만 보면 멀쩡한 뜻이 통째로 버려진다.
    if "→" in g:
        parts=[p.strip() for p in g.split("→")]
        g=next((p for p in reversed(parts) if p), "")
    # 2) "표기 · 품사 · 뜻" 꼴이면 마지막 조각이 뜻이다.
    #    앞 조각이 표제어이거나 품사 이름일 때만 자른다 — 뜻 자체에 든 가운뎃점을 지키려고.
    if " · " in g:
        parts=[p.strip() for p in g.split(" · ")]
        if parts and (parts[0]==head or parts[0].rstrip("다")==head
                      or any(p in POS for p in parts)):
            parts=[p for p in parts if p not in POS and p!=head]
            if parts: g=parts[-1]
    # 3) 모델이 흘린 마크다운 강조(**그**, *그*)를 걷어낸다
    g=re.sub(r"\*{1,3}([^*]+)\*{1,3}", r"\1", g)
    g=g.replace("*","")
    g=re.sub(r"\s+"," ",g).strip().rstrip(".").strip("·-—:：").strip()
    return g

def shorten(g):
    """**뜻은 맞는데 설명이 붙어 길기만 한 것**을 살린다.

    모델은 첫 뜻을 맞히고 나서 설명을 덧붙이는 일이 잦다 —
    `스키야키, 얇게 썬 소고기와 채소를 …` · `단파 (옛 교토, 효고 …)`.
    통째로 버리면 그 낱말은 뜻이 빈 채로 남는데, 앞에 선 뜻은 멀쩡하다.

    **형식을 살리는 것이지 옳고 그름을 보는 것이 아니다.** 첫 뜻이 틀렸다면
    짧게 잘라도 틀린 채로 남는다. 여기서 거르는 것은 모델이 뜻 대신 말을 한
    자리뿐이다(`가장 가까운 한국어 표현으로는 …`).
    """
    # 괄호 안은 설명이다. 짝이 맞는 것만 걷고, 안 맞으면 잘린 것이라 살리지 않는다.
    g=re.sub(r"\s*\([^()]*\)","",g)
    if g.count("(")!=g.count(")"): return None
    g=re.sub(r"\s+"," ",g).strip().strip(",·:→-").strip()

    kept=[]
    for part in (p.strip() for p in g.split(",")):
        # 하나라도 설명이 시작되면 거기서 끊는다. 뒤는 더 볼 것이 없다.
        # 쌍점이 든 조각은 뜻이 아니라 목록의 머리다(`한자 육서: 큰인장, …`).
        if not part or len(part)>MEANING or ":" in part or "：" in part: break
        if CHATTER.search(part): break
        if part in kept: continue          # `식당, 식당` 처럼 같은 말을 두 번 적는다
        if len(", ".join(kept+[part]))>GLOSS: break
        kept.append(part)
        if len(kept)==2: break             # 뜻은 둘까지다
    if not kept: return None
    out=", ".join(kept)
    return out if HANGUL.search(out) else None

rows=[]
for line in open(SRC, encoding="utf-8"):
    line=line.rstrip("\n")
    if line.startswith("#") or not line.strip(): continue
    p=line.split("\t")
    if len(p)==3: rows.append(p)

kept=[]; redo=[]
changed=0
for head, read, gloss in rows:
    g=clean(head, gloss)
    # 영문이 섞였는데 약어(TV·NHK 같은 대문자)가 아니면 옮기다 만 것이다
    eng=re.findall(r"[A-Za-z]+", g)
    half_english = bool(eng) and not all(e.isupper() and len(e)>=2 for e in eng)
    # 길기만 한 것은 앞의 뜻만 남겨 살려 본다. 다른 흠이 있으면 살리지 않는다 —
    # 가나가 남았거나 옮기다 만 것은 잘라도 그대로다.
    if (g and len(g)>GLOSS and HANGUL.search(g) and not KANA.search(g)
            and not HAN.search(g) and not half_english):
        if short := shorten(g): g=short
    bad = (not g or not HANGUL.search(g) or KANA.search(g) or HAN.search(g)
           or len(g)>GLOSS or g.count("(")!=g.count(")") or half_english)
    if bad:
        redo.append((head, read, gloss))
    else:
        if g!=gloss.strip(): changed+=1
        kept.append((head, read, g))

with open(OUT,"w",encoding="utf-8") as f:
    f.write("# 표기\t읽기\t한국어뜻\n")
    for r in kept: f.write("\t".join(r)+"\n")
with open(REDO,"w",encoding="utf-8") as f:
    f.write("# 표기\t읽기\t굽힌 결과(다시 구워야 함)\n")
    for r in redo: f.write("\t".join(r)+"\n")

print(f"원본        {len(rows)}")
print(f"정리본      {len(kept)}   (그중 손본 것 {changed})")
print(f"다시 구울 것 {len(redo)}")

# 정리 뒤 남은 형식 문제
import collections
c=collections.Counter()
for h,rd,g in kept:
    if len(g)>15: c["15자 초과"]+=1
    if "(" in g: c["괄호"]+=1
    if re.search(r"[A-Za-z]", g): c["영문"]+=1
    if g.count(",")>=3: c["뜻 4개 이상"]+=1
print("\n정리본에 남은 것:", dict(c))
