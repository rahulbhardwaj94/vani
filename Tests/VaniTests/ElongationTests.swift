import Foundation
import VaniCore

func elongationTests() {
    // Test validator: a tiny fixed lexicon standing in for the system
    // spell checker the app injects.
    let lexicon: Set<String> = ["google", "so", "no", "cool", "week", "really"]
    func norm(_ s: String) -> String {
        Elongation.normalize(s) { lexicon.contains($0) }
    }

    // The field request: stretched emphasis collapses to the meant word.
    expect(norm("I'm seeing Gooooogle results"), "I'm seeing Google results")
    // Runs collapse to 1 when that's the valid form.
    expect(norm("that took sooooo long"), "that took so long")
    expect(norm("noooooo way"), "no way")
    // Punctuation around the stretch survives.
    expect(norm("Gooooogle, obviously."), "Google, obviously.")
    // Legitimate double letters are never touched (no 3+ run).
    expect(norm("this week was cool"), "this week was cool")
    // A stretch with no valid collapse stays exactly as spoken.
    expect(norm("aaaaargh that hurt"), "aaaaargh that hurt")
    // Devanagari and mixed tokens pass through.
    expect(norm("वो लेट आएगा"), "वो लेट आएगा")
    // Case is preserved from the original.
    expect(norm("REALLYYYY good"), "REALLY good")
    expect(norm("Reallyyyy good"), "Really good")
}
