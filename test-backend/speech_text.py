"""Make text safe to read aloud.

Text-to-speech voices often garble money ("£3.60" read as "three thousand
sixty"), so every amount is rewritten in British English words before it is
sent to ElevenLabs: "£3.60" -> "three pounds sixty", "50p" -> "fifty pence".
"""
from __future__ import annotations

import re

_ONES = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
         "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
_TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
_SCALES = [(10**12, "trillion"), (10**9, "billion"), (10**6, "million"), (1000, "thousand")]


def _under_thousand(n: int) -> str:
    hundreds, rest = divmod(n, 100)
    parts = []
    if hundreds:
        parts.append(f"{_ONES[hundreds]} hundred")
    if rest:
        if rest < 20:
            words = _ONES[rest]
        else:
            tens, ones = divmod(rest, 10)
            words = _TENS[tens] + (f"-{_ONES[ones]}" if ones else "")
        parts.append(("and " if hundreds else "") + words)
    return " ".join(parts)


def number_to_words(n: int) -> str:
    """British English: 1240 -> 'one thousand, two hundred and forty'."""
    if n == 0:
        return "zero"
    if n < 0:
        return "minus " + number_to_words(-n)
    chunks = []
    for value, name in _SCALES:
        if n >= value:
            count, n = divmod(n, value)
            chunks.append(f"{number_to_words(count)} {name}")
    if n:
        # "one thousand and five", but "one thousand, two hundred"
        if chunks and n < 100:
            return " ".join([", ".join(chunks), "and", _under_thousand(n)])
        chunks.append(_under_thousand(n))
    return ", ".join(chunks)


def _pounds(whole: int, pence: int) -> str:
    if whole == 0 and pence:
        return f"{number_to_words(pence)} {'penny' if pence == 1 else 'pence'}"
    words = f"{number_to_words(whole)} {'pound' if whole == 1 else 'pounds'}"
    if pence:
        words += f" {number_to_words(pence)}"
    return words


_SCALE_WORDS = {"k": "thousand", "m": "million", "bn": "billion", "b": "billion",
                "thousand": "thousand", "million": "million", "billion": "billion"}

# £1,240.50 / £3.60 / £5 / £2.3k / £1.5m / £12 million / -£277 / −£277
_POUND_RE = re.compile(
    r"(?P<neg>(?<![\w£])[-−–]\s?)?£\s?(?P<num>\d{1,3}(?:,\d{3})+|\d+)(?:\.(?P<dec>\d{1,2})(?!\d))?"
    r"(?:\s?(?P<scale>k|m|bn|b|thousand|million|billion)\b)?",
    re.IGNORECASE,
)
# 50p / 99p
_PENCE_RE = re.compile(r"\b(?P<num>\d{1,2})p\b")
# "GBP 40" / "40 GBP"
_GBP_RE = re.compile(r"\bGBP\s?(\d[\d,]*(?:\.\d{1,2})?)\b|\b(\d[\d,]*(?:\.\d{1,2})?)\s?GBP\b")


def _pound_sub(m: re.Match) -> str:
    whole = int(m.group("num").replace(",", ""))
    dec = m.group("dec")
    scale = (m.group("scale") or "").lower()
    neg = "minus " if m.group("neg") else ""
    if scale:
        scale_word = _SCALE_WORDS[scale]
        if dec:
            digits = " ".join(_ONES[int(d)] for d in dec.rstrip("0")) or "zero"
            return f"{neg}{number_to_words(whole)} point {digits} {scale_word} pounds"
        return f"{neg}{number_to_words(whole)} {scale_word} pounds"
    pence = int(dec.ljust(2, "0")) if dec else 0
    return neg + _pounds(whole, pence)


def _gbp_sub(m: re.Match) -> str:
    raw = (m.group(1) or m.group(2)).replace(",", "")
    whole, _, dec = raw.partition(".")
    return _pounds(int(whole), int(dec.ljust(2, "0")) if dec else 0)


def _pence_sub(m: re.Match) -> str:
    n = int(m.group("num"))
    return f"{number_to_words(n)} {'penny' if n == 1 else 'pence'}"


def speakable(text: str) -> str:
    """Rewrite money amounts as words so the voice reads them correctly."""
    text = _POUND_RE.sub(_pound_sub, text)
    text = _PENCE_RE.sub(_pence_sub, text)
    text = _GBP_RE.sub(_gbp_sub, text)
    return text
