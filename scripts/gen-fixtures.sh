#!/bin/bash
# Generates the synthetic regression fixtures in fixtures/: macOS TTS
# renders the calibration scripts (Aman en_IN for English, Lekha hi_IN for
# Hindi), [[slnc N]] markers create real pauses so the VAD/chunking paths
# are exercised, and ffmpeg derives degraded variants (quiet mic, room
# noise, faster speech). Each <name>.wav gets a sidecar <name>.txt with the
# expected transcript. Run once (and re-run only when scripts change);
# then: swift run -c release VaniRegress [--update-baseline]
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p fixtures build/tts
rm -f build/tts/*

say_wav() { # $1 voice, $2 out.wav, $3 text
  local aiff="build/tts/$(basename "$2" .wav).aiff"
  say -v "$1" -o "$aiff" "$3"
  afconvert -f WAVE -d LEI16@16000 -c 1 "$aiff" "$2"
}

# ---------- script 1: long English ramble with real pauses ----------
say_wav Aman fixtures/s1-ramble.wav \
  "So I have been thinking about the roadmap for next quarter, [[slnc 700]] and I feel like we should focus on reliability before adding anything new. [[slnc 900]] The dictation should work every single time, [[slnc 500]] without fail, even when I pause for a long moment, [[slnc 2200]] like this one. [[slnc 800]] Then after that we can look at the fancier features, maybe the wake word, maybe voice editing. [[slnc 700]] But honestly, accuracy comes first, speed comes second, and everything else is a distant third."
cat > fixtures/s1-ramble.txt <<'TXT'
So I have been thinking about the roadmap for next quarter, and I feel like we should focus on reliability before adding anything new. The dictation should work every single time, without fail, even when I pause for a long moment, like this one. Then after that we can look at the fancier features, maybe the wake word, maybe voice editing. But honestly, accuracy comes first, speed comes second, and everything else is a distant third.
TXT

# ---------- script 3: technical vocabulary ----------
say_wav Aman fixtures/s3-technical.wav \
  "Vani uses WhisperKit on the neural engine, [[slnc 600]] with SwiftUI for the menu bar and Ollama for cleanup. [[slnc 800]] The incremental transcriber decodes chunks while I speak, [[slnc 600]] and the adaptive VAD threshold handles my quiet microphone. [[slnc 700]] Push the build to GitHub and update the Homebrew cask."
cat > fixtures/s3-technical.txt <<'TXT'
Vani uses WhisperKit on the neural engine, with SwiftUI for the menu bar and Ollama for cleanup. The incremental transcriber decodes chunks while I speak, and the adaptive VAD threshold handles my quiet microphone. Push the build to GitHub and update the Homebrew cask.
TXT

# ---------- script 5: numbers, dates, names ----------
say_wav Aman fixtures/s5-numbers.wav \
  "The meeting is on July fifteenth at nine thirty. [[slnc 700]] Call Abhinav at nine eight seven six five four three two one zero. [[slnc 700]] The budget is twenty five thousand rupees, split across three months."
cat > fixtures/s5-numbers.txt <<'TXT'
The meeting is on July 15th at 9.30. Call Abhinav at 9876543210. The budget is 25,000 rupees, split across three months.
TXT

# ---------- script 2: Hinglish code-switch (spliced Aman + Lekha) ----------
say_wav Aman  build/tts/s2-a.wav "Send the invoice tonight,"
say_wav Lekha build/tts/s2-b.wav "बाक़ी डिटेल्स कल डिस्कस करेंगे।"
say_wav Aman  build/tts/s2-c.wav "The meeting is at ten,"
say_wav Lekha build/tts/s2-d.wav "लेकिन मुझे लगता है वो लेट आएगा।"
say_wav Aman  build/tts/s2-e.wav "Ship it now,"
say_wav Lekha build/tts/s2-f.wav "क्योंकि परफेक्ट कभी नहीं होगा।"
# 0.5 s of silence between parts (a real breath, enough for the VAD split)
ffmpeg -y -loglevel error -f lavfi -i anullsrc=r=16000:cl=mono -t 0.5 \
  -c:a pcm_s16le build/tts/gap.wav
ffmpeg -y -loglevel error \
  -i build/tts/s2-a.wav -i build/tts/gap.wav -i build/tts/s2-b.wav \
  -i build/tts/gap.wav -i build/tts/s2-c.wav -i build/tts/gap.wav \
  -i build/tts/s2-d.wav -i build/tts/gap.wav -i build/tts/s2-e.wav \
  -i build/tts/gap.wav -i build/tts/s2-f.wav \
  -filter_complex "concat=n=11:v=0:a=1" -ar 16000 -ac 1 -c:a pcm_s16le \
  fixtures/s2-hinglish.wav
cat > fixtures/s2-hinglish.txt <<'TXT'
Send the invoice tonight, बाक़ी details कल discuss करेंगे। The meeting is at ten, लेकिन मुझे लगता है वो late आएगा। Ship it now, क्योंकि perfect कभी नहीं होगा।
TXT

# ---------- degraded variants of script 1 ----------
# Quiet mic (the field bug that broke the fixed VAD threshold).
ffmpeg -y -loglevel error -i fixtures/s1-ramble.wav \
  -af "volume=0.12" -c:a pcm_s16le fixtures/s1-quiet.wav
cp fixtures/s1-ramble.txt fixtures/s1-quiet.txt
# Room noise under the voice.
ffmpeg -y -loglevel error -i fixtures/s1-ramble.wav \
  -filter_complex "anoisesrc=r=16000:c=pink:a=0.015[n];[0:a][n]amix=inputs=2:duration=first" \
  -ac 1 -ar 16000 -c:a pcm_s16le fixtures/s1-noisy.wav
cp fixtures/s1-ramble.txt fixtures/s1-noisy.txt
# Faster speaker.
ffmpeg -y -loglevel error -i fixtures/s1-ramble.wav \
  -af "atempo=1.2" -c:a pcm_s16le fixtures/s1-fast.wav
cp fixtures/s1-ramble.txt fixtures/s1-fast.txt

ls -la fixtures/*.wav
echo "fixtures generated. Next: swift run -c release VaniRegress --update-baseline"
