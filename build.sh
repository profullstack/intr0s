#!/usr/bin/env bash
#
# AgenticIntros — build script
#
# Regenerates the repo's media artifacts from their sources:
#
#   intro       Render the branded intro into mp4 / webm / mp3 / wav
#               from the logo source clip.
#   transcribe  Extract audio (wav) from a long-form recording and run
#               Whisper to produce transcript/{json,srt,tsv,txt,vtt}.
#   all         Run both of the above.
#
# Usage:
#   ./build.sh intro       [SOURCE_VIDEO]   (default: Profullstack_Logo_Intro_7s_blank_fadeblack.mp4)
#   ./build.sh transcribe  [INPUT_VIDEO]    (default: input.webm)
#   ./build.sh all
#
# Requires: ffmpeg, ffprobe, whisper (openai-whisper).

set -euo pipefail

# --- config -----------------------------------------------------------------
INTRO_SRC="${INTRO_SRC:-Profullstack_Logo_Intro_7s_blank_fadeblack.mp4}"
INPUT_SRC="${INPUT_SRC:-input.webm}"
WHISPER_MODEL="${WHISPER_MODEL:-small}"
WHISPER_LANG="${WHISPER_LANG:-en}"
TRANSCRIPT_DIR="${TRANSCRIPT_DIR:-transcript}"

# --- helpers ----------------------------------------------------------------
log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }

dur()  { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }

# --- steps ------------------------------------------------------------------
build_intro() {
  need ffmpeg
  [ -f "$INTRO_SRC" ] || die "intro source not found: $INTRO_SRC"
  log "Rendering intro from: $INTRO_SRC ($(dur "$INTRO_SRC")s)"

  # MP4 — H.264 video + AAC audio (web-friendly, faststart for streaming).
  log "intro.mp4  (H.264 / AAC)"
  ffmpeg -y -loglevel error -i "$INTRO_SRC" \
    -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p \
    -c:a aac -b:a 192k -movflags +faststart \
    intro.mp4

  # WebM — VP9 video + Opus audio.
  log "intro.webm (VP9 / Opus)"
  ffmpeg -y -loglevel error -i "$INTRO_SRC" \
    -c:v libvpx-vp9 -crf 32 -b:v 0 -row-mt 1 \
    -c:a libopus -b:a 128k \
    intro.webm

  # WAV — lossless PCM audio.
  log "intro.wav  (PCM s16le)"
  ffmpeg -y -loglevel error -i "$INTRO_SRC" -vn -c:a pcm_s16le intro.wav

  # MP3 — compressed audio.
  log "intro.mp3  (MP3 320k)"
  ffmpeg -y -loglevel error -i "$INTRO_SRC" -vn -c:a libmp3lame -b:a 320k intro.mp3

  log "Intro artifacts written: intro.mp4 intro.webm intro.wav intro.mp3"
}

build_transcripts() {
  need ffmpeg
  need whisper
  [ -f "$INPUT_SRC" ] || die "input recording not found: $INPUT_SRC"

  local stem wav
  stem="$(basename "${INPUT_SRC%.*}")"
  wav="${stem}.wav"

  log "Extracting audio: $INPUT_SRC -> $wav ($(dur "$INPUT_SRC")s)"
  # 16 kHz mono PCM is what Whisper consumes; also serves as the archived wav.
  ffmpeg -y -loglevel error -i "$INPUT_SRC" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$wav"

  mkdir -p "$TRANSCRIPT_DIR"
  log "Transcribing with Whisper (model=$WHISPER_MODEL, lang=$WHISPER_LANG)"
  whisper "$wav" \
    --model "$WHISPER_MODEL" \
    --language "$WHISPER_LANG" \
    --task transcribe \
    --output_format all \
    --output_dir "$TRANSCRIPT_DIR"

  log "Transcripts written to $TRANSCRIPT_DIR/: $(ls "$TRANSCRIPT_DIR" | tr '\n' ' ')"
}

# --- dispatch ---------------------------------------------------------------
cmd="${1:-all}"
case "$cmd" in
  intro)      build_intro ;;
  transcribe) build_transcripts ;;
  all)        build_intro; build_transcripts ;;
  -h|--help|help)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *) die "unknown command: $cmd (try: intro | transcribe | all | --help)" ;;
esac

log "Done."
