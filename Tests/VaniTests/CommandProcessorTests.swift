import VaniCore

func commandProcessorTests() {
    // Line breaks (spec acceptance case).
    expect(
        CommandProcessor.apply(to: "first point new line second point"),
        "first point\nSecond point"
    )
    // Whisper punctuating the command itself.
    expect(
        CommandProcessor.apply(to: "First point. New line. Second point."),
        "First point.\nSecond point."
    )
    expect(
        CommandProcessor.apply(to: "intro new paragraph details"),
        "intro\n\nDetails"
    )

    // Phrases used as nouns stay literal (spec acceptance case).
    expect(
        CommandProcessor.apply(to: "I added a new line of code"),
        "I added a new line of code"
    )
    expect(
        CommandProcessor.apply(to: "add a comma here"),
        "add a comma here"
    )
    expect(
        CommandProcessor.apply(to: "the new paragraph looks good"),
        "the new paragraph looks good"
    )

    // Punctuation attaches to the previous word, next sentence capitalized.
    expect(
        CommandProcessor.apply(to: "stop here full stop next thing"),
        "stop here. Next thing"
    )
    expect(
        CommandProcessor.apply(to: "are you coming question mark"),
        "are you coming?"
    )
    expect(
        CommandProcessor.apply(to: "one comma two comma three"),
        "one, two, three"
    )
    expect(
        CommandProcessor.apply(to: "That's all, full stop."),
        "That's all."
    )
    expect(
        CommandProcessor.apply(to: "what a day exclamation mark"),
        "what a day!"
    )

    // Hindi triggers (spec acceptance case).
    expect(
        CommandProcessor.apply(to: "मेरा नाम राहुल है नई लाइन धन्यवाद"),
        "मेरा नाम राहुल है\nधन्यवाद"
    )
    expect(
        CommandProcessor.apply(to: "आप आ रहे हैं प्रश्न चिह्न"),
        "आप आ रहे हैं?"
    )

    // Discard commands (spec acceptance case).
    expect(CommandProcessor.apply(to: "blah blah scratch that"), "")
    expect(CommandProcessor.apply(to: "blah blah scratch that."), "")
    expect(CommandProcessor.apply(to: "कुछ लिखा था रहने दो"), "")
    // "scratch" mid-sentence is not a discard.
    expect(
        CommandProcessor.apply(to: "scratch that idea off the list please"),
        "scratch that idea off the list please"
    )

    // Command words inside other words never trigger.
    expect(CommandProcessor.apply(to: "the recommandation stands"), "the recommandation stands")

    // Text without commands passes through untouched.
    expect(
        CommandProcessor.apply(to: "Vani uses WhisperKit with CoreML."),
        "Vani uses WhisperKit with CoreML."
    )
}
