#!/bin/bash
#===============================================================================
# sound_diag.sh — Quick sound diagnostic for Slackware
#===============================================================================
#
# PURPOSE:
#   This script tests sound on a Slackware system. It checks for:
#     1. Kernel version
#     2. Audio hardware (lspci)
#     3. Loaded kernel sound modules
#     4. ALSA card/device presence
#     5. PipeWire or PulseAudio service
#     6. Simple playback test (if test WAV file exists)
#
# OUTPUT:
#   - Default: short, clear diagnostics
#   - -v: verbose (full hardware/modules/logs)
#   - -q: quiet (no output, exit code only)
#
# EXIT CODES:
#   0 = All checks passed
#   1 = No audio hardware detected
#   2 = No kernel sound modules loaded
#   3 = No ALSA cards detected
#   4 = No sound server running (PipeWire/PulseAudio)
#   5 = Playback test failed
#
# INSTALLATION:
#   1. Save this script as: sound_diag.sh
#   2. Make it executable:
#        chmod +x sound_diag.sh
#   3. Run it:
#        ./sound_diag.sh
#      Verbose:
#        ./sound_diag.sh -v
#      Quiet:
#        ./sound_diag.sh -q
#
#===============================================================================

VERBOSE=0
QUIET=0

case "${1:-}" in
    -v) VERBOSE=1 ;;
    -q) QUIET=1 ;;
esac

print() {
    [ $QUIET -eq 0 ] && echo "$@"
}

print "===== Slackware Sound Diagnostics ====="

# Kernel version
print -n "Kernel: "
[ $QUIET -eq 0 ] && uname -r >/dev/stdout

# Hardware detection
AUDIO_HW=$(lspci -nn | grep -i audio | cut -d':' -f3- | sed 's/^ *//')
if [ -z "$AUDIO_HW" ]; then
    print "Audio devices (lspci): none"
    exit 1
else
    print "Audio devices (lspci): $AUDIO_HW"
    if [ $VERBOSE -eq 1 ]; then
        print "  (full lspci):"
        lspci -nn | grep -i audio
    fi
fi

# Kernel modules
SND_MODS=$(lsmod | grep -E '^(snd|snd_|sound|sof_|snd_hda|snd_soc)' | awk '{print $1}')
if [ -z "$SND_MODS" ]; then
    print "Sound modules loaded: none"
    exit 2
else
    print -n "Sound modules loaded: "
    print "$SND_MODS" | tr '\n' ' '
    [ $VERBOSE -eq 1 ] && { print "  (full lsmod):"; lsmod | grep snd; }
fi

# ALSA cards
ALSA_CARDS=$(aplay -l 2>/dev/null | grep '^card' | cut -d':' -f1-2)
if [ -z "$ALSA_CARDS" ]; then
    print "ALSA cards: none"
    exit 3
else
    print -n "ALSA cards: "
    print "$ALSA_CARDS" | tr '\n' ' '
fi

# ALSA devices
[ $QUIET -eq 0 ] && {
    echo -n "ALSA devices: "
    aplay -L 2>/dev/null | grep -E '^(default|hw:|plughw:)' | head -n 3 | tr '\n' ' '
    echo
}

# PipeWire or PulseAudio status
if pgrep -x pipewire >/dev/null 2>&1; then
    print "PipeWire: running"
elif pgrep -x pulseaudio >/dev/null 2>&1; then
    print "PulseAudio: running"
else
    print "PipeWire/PulseAudio: not running"
    exit 4
fi

# Quick playback test
TESTWAV="/usr/share/sounds/alsa/Front_Center.wav"
if [ -f "$TESTWAV" ]; then
    if aplay -q "$TESTWAV"; then
        print "Playback test: ok"
    else
        print "Playback test: fail"
        exit 5
    fi
fi

# Verbose logs
if [ $VERBOSE -eq 1 ]; then
    print
    print "===== Verbose Diagnostics ====="
    print "--- dmesg (snd/sof/audio) ---"
    dmesg | grep -iE 'snd|sof|audio' | tail -n 20
    if command -v journalctl >/dev/null 2>&1; then
        print "--- journalctl (recent audio logs) ---"
        journalctl -b | grep -iE 'snd|sof|audio' | tail -n 20
    fi
fi

print "===== End of diagnostics ====="
exit 0

