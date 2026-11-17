#!/bin/zsh
# Captures Mus'haf's Mac App Store screenshots from the real app (build/Mushaf.app, from make-app.sh), in
# English, French and Arabic, into ../../ios-assets/appstore-assets/mac/<lang>/. Run on a Mac with a screen.
set -uo pipefail
cd "$(dirname "$0")"
APP=../build/Mushaf.app
OUT=../../ios-assets/appstore-assets/mac
ID=com.mushaf.mac
swiftc -O window-id.swift -o "$TMPDIR/window-id"
swiftc -O compose.swift -o "$TMPDIR/compose"

typeset -A CAP
CAP[en.1]="The authentic Madinah Mushaf, two pages side by side"
CAP[en.2]="Tafsir and translations beside every verse"
CAP[en.3]="Night mode, and 26 reciters verse by verse"
CAP[en.4]="Free, as a Sadaqa Jariyah: no ads, no account"
CAP[fr.1]="Le Mushaf de Médine authentique, en double page"
CAP[fr.2]="Tafsir et traductions à côté de chaque verset"
CAP[fr.3]="Mode nuit et 26 récitants, verset par verset"
CAP[fr.4]="Gratuit, en Sadaqa Jariyah : sans pub ni compte"
CAP[ar.1]="مصحف المدينة المنورة كما هو، صفحتان متقابلتان"
CAP[ar.2]="التفسير والترجمة بجانب كل آية"
CAP[ar.3]="الوضع الليلي و٢٦ قارئًا آيةً آية"
CAP[ar.4]="مجاني صدقةً جارية: بلا إعلانات ولا حساب"

quit() { osascript -e 'quit app "Mushaf"' 2>/dev/null; pkill -x Mushaf 2>/dev/null; sleep 3; }
launch() { open "$APP"; sleep 30; }
link() { open "$1"; sleep 20; }
grab() {  # grab <lang> <n>
  local id; id=$("$TMPDIR/window-id") || { echo "no window for $1.$2"; screencapture -x "$OUT/debug-$1-$2.png"; return; }
  screencapture -x -o -l"$id" "$TMPDIR/raw.png" && "$TMPDIR/compose" "$TMPDIR/raw.png" "$OUT/$1/0$2.png" "${CAP[$1.$2]}" \
    && echo "$1/0$2.png"
}

for lang in en fr ar; do
  mkdir -p "$OUT/$lang"
  quit
  defaults delete $ID 2>/dev/null
  defaults write $ID language "$lang"
  defaults write $ID pagesChoiceMade -bool true
  defaults write $ID kahfAsked -bool true
  defaults write $ID kahfReminder -bool false
  defaults write $ID dualPage -bool true
  defaults write $ID theme Coloured
  defaults write $ID lastUpdateCheck -float "$(date +%s)"
  launch
  grab $lang 4                                    # the opening page
  link "mushaf://surah/1";        grab $lang 1    # Al-Fatiha and Al-Baqara, side by side
  link "mushaf://tafsir/2/255";   grab $lang 2    # Ayat al-Kursi with its tafsir
  quit
  defaults write $ID theme Night
  launch
  link "mushaf://surah/18";       grab $lang 3    # Al-Kahf at night
done
quit
