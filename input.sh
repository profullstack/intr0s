#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./make-intro.sh input.webm
#   ./make-intro.sh input.webm intro
#
# Generates:
#   intro.mp4
#   intro.webm
#   intro.wav
#   intro.mp3
#   intro.mov
#   intro.mkv
#   intro.m4a
#   intro.aac
#   intro.flac

INPUT="${1:-input.webm}"
BASENAME="${2:-intro}"
DURATION="${DURATION:-10}"
FADE_IN="${FADE_IN:-0.25}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg is not installed or not in PATH." >&2
  exit 1
fi

if [[ ! -f "$INPUT" ]]; then
  echo "Error: input file not found: $INPUT" >&2
  exit 1
fi

echo "Generating ${DURATION}s intro from: $INPUT"

# Canonical source file: MP4
ffmpeg -y -i "$INPUT" \
  -filter_complex "[0:v]trim=0:${DURATION},setpts=PTS-STARTPTS,fade=t=in:st=0:d=${FADE_IN},format=yuv420p[v];[0:a]atrim=0:${DURATION},asetpts=PTS-STARTPTS,afade=t=in:st=0:d=${FADE_IN}[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -ac 2 \
  -movflags +faststart \
  "${BASENAME}.mp4"

# WebM
ffmpeg -y -i "${BASENAME}.mp4" \
  -c:v libvpx-vp9 -b:v 0 -crf 30 \
  -c:a libopus -b:a 128k \
  "${BASENAME}.webm"

# WAV
ffmpeg -y -i "${BASENAME}.mp4" \
  -vn -c:a pcm_s16le -ar 48000 -ac 2 \
  "${BASENAME}.wav"

# MP3
ffmpeg -y -i "${BASENAME}.mp4" \
  -vn -c:a libmp3lame -b:a 192k -ar 48000 -ac 2 \
  "${BASENAME}.mp3"

# MOV
ffmpeg -y -i "${BASENAME}.mp4" \
  -c:v copy -c:a copy \
  -movflags +faststart \
  "${BASENAME}.mov"

# MKV
ffmpeg -y -i "${BASENAME}.mp4" \
  -c:v copy -c:a copy \
  "${BASENAME}.mkv"

# M4A
ffmpeg -y -i "${BASENAME}.mp4" \
  -vn -c:a aac -b:a 192k -ar 48000 -ac 2 \
  "${BASENAME}.m4a"

# AAC
ffmpeg -y -i "${BASENAME}.mp4" \
  -vn -c:a aac -b:a 192k -ar 48000 -ac 2 \
  "${BASENAME}.aac"

# FLAC
ffmpeg -y -i "${BASENAME}.mp4" \
  -vn -c:a flac -ar 48000 -ac 2 \
  "${BASENAME}.flac"

echo
echo "Done:"
ls -lh "${BASENAME}".{mp4,webm,wav,mp3,mov,mkv,m4a,aac,flac}
