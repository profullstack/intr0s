#!/usr/bin/env bash
set -euo pipefail

# episodes.sh
#
# Usage:
#   ./episodes.sh <namespace> <path-to-webm-or-mp4> [episode-number] [video-title]
#
# Example:
#   ./episodes.sh "@profullstack" "./@profullstack/Truly Tasteless Memes.webm" 1 "The AI Founder"
#
# Output:
#   ./profullstack/truly-tasteless-memes__episode-001-the-ai-founder.mp4
#   ./profullstack/truly-tasteless-memes__episode-001-the-ai-founder.webm
#   ./profullstack/truly-tasteless-memes__episode-001-the-ai-founder.wav
#   ./profullstack/truly-tasteless-memes__episode-001-the-ai-founder.mp3
#   ./profullstack/truly-tasteless-memes__episode-001-the-ai-founder.txt
#
# Optional env vars:
#   MODEL=small ./episodes.sh ...
#   MODEL=medium FORMAT=srt ./episodes.sh ...
#   DURATION=10 ./episodes.sh ...
#   FADE_IN=0.25 ./episodes.sh ...

NAMESPACE="${1:-}"
SOURCE_FILE="${2:-}"
EPISODE_NUMBER="${3:-1}"
VIDEO_TITLE="${4:-}"

MODEL="${MODEL:-medium}"
LANGUAGE="${LANGUAGE:-English}"
FORMAT="${FORMAT:-txt}"
DURATION="${DURATION:-10}"
FADE_IN="${FADE_IN:-0.25}"

if [[ -z "$NAMESPACE" || -z "$SOURCE_FILE" ]]; then
  echo "Usage:"
  echo "  ./episodes.sh <namespace> <path-to-webm-or-mp4> [episode-number] [video-title]"
  echo
  echo "Example:"
  echo "  ./episodes.sh \"@profullstack\" \"./@profullstack/Truly Tasteless Memes.webm\" 1 \"The AI Founder\""
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg is not installed."
  echo
  echo "Ubuntu install:"
  echo "  sudo apt update && sudo apt install -y ffmpeg"
  exit 1
fi

if ! command -v whisper >/dev/null 2>&1; then
  echo "ERROR: whisper command not found."
  echo
  echo "Install OpenAI Whisper:"
  echo "  pipx install openai-whisper"
  echo "  pipx ensurepath"
  echo "  exec \"\$SHELL\""
  exit 1
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "ERROR: source file not found:"
  echo "  $SOURCE_FILE"
  exit 1
fi

EXT="${SOURCE_FILE##*.}"
EXT_LOWER="$(printf '%s' "$EXT" | tr '[:upper:]' '[:lower:]')"

case "$EXT_LOWER" in
  webm|mp4)
    ;;
  *)
    echo "ERROR: source file must be .webm or .mp4"
    echo "Got: .$EXT_LOWER"
    exit 1
    ;;
esac

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/@//g; s/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

pad_episode() {
  printf "%03d" "$1"
}

SOURCE_BASENAME="$(basename "$SOURCE_FILE")"
SOURCE_TITLE="${SOURCE_BASENAME%.*}"

# If no explicit video title is passed, use the source filename as the title.
if [[ -z "$VIDEO_TITLE" ]]; then
  VIDEO_TITLE="$SOURCE_TITLE"
fi

NAMESPACE_SLUG="$(slugify "$NAMESPACE")"
PLAYLIST_TITLE="$SOURCE_TITLE"
PLAYLIST_SLUG="$(slugify "$PLAYLIST_TITLE")"
VIDEO_TITLE_SLUG="$(slugify "$VIDEO_TITLE")"
EPISODE_PADDED="$(pad_episode "$EPISODE_NUMBER")"

OUTPUT_DIR="./${NAMESPACE_SLUG}"
BASE_NAME="${PLAYLIST_SLUG}__episode-${EPISODE_PADDED}-${VIDEO_TITLE_SLUG}"

MP4_FILE="${OUTPUT_DIR}/${BASE_NAME}.mp4"
WEBM_FILE="${OUTPUT_DIR}/${BASE_NAME}.webm"
WAV_FILE="${OUTPUT_DIR}/${BASE_NAME}.wav"
MP3_FILE="${OUTPUT_DIR}/${BASE_NAME}.mp3"
TRANSCRIPT_FILE="${OUTPUT_DIR}/${BASE_NAME}.${FORMAT}"

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "Episode generator"
echo "========================================"
echo "Namespace:      $NAMESPACE"
echo "Source:         $SOURCE_FILE"
echo "Playlist title: $PLAYLIST_TITLE"
echo "Video title:    $VIDEO_TITLE"
echo "Episode:        $EPISODE_PADDED"
echo "Output dir:     $OUTPUT_DIR"
echo "Base name:      $BASE_NAME"
echo "Model:          $MODEL"
echo "Language:       $LANGUAGE"
echo "Format:         $FORMAT"
echo "========================================"
echo

echo "Generating MP4:"
echo "  $MP4_FILE"

ffmpeg -y -i "$SOURCE_FILE" \
  -filter_complex "[0:v]trim=0:${DURATION},setpts=PTS-STARTPTS,fade=t=in:st=0:d=${FADE_IN},format=yuv420p[v];[0:a]atrim=0:${DURATION},asetpts=PTS-STARTPTS,afade=t=in:st=0:d=${FADE_IN}[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -ac 2 \
  -movflags +faststart \
  "$MP4_FILE"

echo
echo "Generating WebM:"
echo "  $WEBM_FILE"

ffmpeg -y -i "$MP4_FILE" \
  -c:v libvpx-vp9 -b:v 0 -crf 30 \
  -c:a libopus -b:a 128k \
  "$WEBM_FILE"

echo
echo "Generating WAV:"
echo "  $WAV_FILE"

ffmpeg -y -i "$MP4_FILE" \
  -vn -c:a pcm_s16le -ar 16000 -ac 1 \
  "$WAV_FILE"

echo
echo "Generating MP3:"
echo "  $MP3_FILE"

ffmpeg -y -i "$MP4_FILE" \
  -vn -c:a libmp3lame -b:a 192k -ar 48000 -ac 2 \
  "$MP3_FILE"

echo
echo "Transcribing:"
echo "  $WAV_FILE"

whisper "$WAV_FILE" \
  --model "$MODEL" \
  --language "$LANGUAGE" \
  --task transcribe \
  --output_format "$FORMAT" \
  --output_dir "$OUTPUT_DIR"

# Whisper outputs based on the WAV filename, so this should already match.
if [[ ! -f "$TRANSCRIPT_FILE" ]]; then
  echo
  echo "WARNING: expected transcript not found:"
  echo "  $TRANSCRIPT_FILE"
  echo
  echo "Files in output dir:"
  ls -lah "$OUTPUT_DIR"
  exit 1
fi

echo
echo "========================================"
echo "Done."
echo "Generated:"
echo "  $MP4_FILE"
echo "  $WEBM_FILE"
echo "  $WAV_FILE"
echo "  $MP3_FILE"
echo "  $TRANSCRIPT_FILE"
echo "========================================"
