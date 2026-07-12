import Foundation
import VaniCore

func numberWordsTests() {
    // Ports and years — adjacent groups concatenate.
    expect(NumberWords.apply(to: "port eighty eighty"), "port 8080")
    expect(NumberWords.apply(to: "in twenty twenty six"), "in 2026")

    // Single-digit runs concatenate.
    expect(NumberWords.apply(to: "eight zero eight zero"), "8080")
    expect(NumberWords.apply(to: "one two three"), "123")

    // Arithmetic composition.
    expect(NumberWords.apply(to: "one hundred and five"), "105")
    expect(NumberWords.apply(to: "three thousand two hundred"), "3200")
    expect(NumberWords.apply(to: "twenty-one items"), "21 items")
    expect(NumberWords.apply(to: "chapter nineteen"), "chapter 19")
    expect(NumberWords.apply(to: "timeout of thirty seconds"), "timeout of 30 seconds")

    // A lone "one" is a pronoun more often than a number.
    expect(NumberWords.apply(to: "the one thing that matters"), "the one thing that matters")

    // Non-numbers untouched; number-ish substrings inside words untouched.
    expect(NumberWords.apply(to: "nobody wondered"), "nobody wondered")
    expect(NumberWords.apply(to: "the tension is high"), "the tension is high")

    // Two separate numbers stay separate when words intervene.
    expect(NumberWords.apply(to: "five retries and seven workers"), "5 retries and 7 workers")
}
