import pytest

from speech_text import number_to_words, speakable


@pytest.mark.parametrize("n, words", [
    (0, "zero"),
    (7, "seven"),
    (15, "fifteen"),
    (40, "forty"),
    (41, "forty-one"),
    (100, "one hundred"),
    (105, "one hundred and five"),
    (240, "two hundred and forty"),
    (1000, "one thousand"),
    (1005, "one thousand and five"),
    (1240, "one thousand, two hundred and forty"),
    (12356, "twelve thousand, three hundred and fifty-six"),
    (2_000_000, "two million"),
])
def test_number_to_words(n, words):
    assert number_to_words(n) == words


@pytest.mark.parametrize("text, expected", [
    ("£3.60", "three pounds sixty"),
    ("£1,240", "one thousand, two hundred and forty pounds"),
    ("£41.33 a day", "forty-one pounds thirty-three a day"),
    ("£1", "one pound"),
    ("£1.05", "one pound five"),
    ("£0.50", "fifty pence"),
    ("£12.4", "twelve pounds forty"),
    ("50p", "fifty pence"),
    ("1p", "one penny"),
    ("-£277", "minus two hundred and seventy-seven pounds"),
    ("−£277", "minus two hundred and seventy-seven pounds"),
    ("£2.3k", "two point three thousand pounds"),
    ("£5k", "five thousand pounds"),
    ("£1.5m", "one point five million pounds"),
    ("£12 million", "twelve million pounds"),
    ("40 GBP", "forty pounds"),
])
def test_speakable_money(text, expected):
    assert speakable(text) == expected


def test_sentence_keeps_other_text():
    text = "You spent £1,240 this month. A coffee costs £3.60, and 50p goes in the jar. That's 12% of income."
    assert speakable(text) == (
        "You spent one thousand, two hundred and forty pounds this month. A coffee costs three pounds sixty, "
        "and fifty pence goes in the jar. That's 12% of income."
    )


def test_leaves_non_money_alone():
    assert speakable("It is 10 degrees in Manchester") == "It is 10 degrees in Manchester"
    assert speakable("A 50mph road") == "A 50mph road"
    assert speakable("Spending fell 5-10% this week") == "Spending fell 5-10% this week"
