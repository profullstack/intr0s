# AgenticIntros

Branded, AI-generated video intros for Profullstack and related projects, plus their transcripts.

<video src="intro.mp4" controls preload="metadata" width="640">
  Your browser can't play embedded video.
  <a href="intro.mp4">Download intro.mp4</a> instead.
</video>

> The `<video>` player renders on GitHub only when `intro.mp4` is tracked in the
> repo. It's currently gitignored (see [Note on media files](#note-on-media-files));
> the clip is ~3 MB, so it can be force-added if you want it to play inline.

## Contents

- `intro.*` — the rendered Profullstack intro in multiple formats (mp3, mp4, wav, webm).
- `Profullstack_Logo_Intro_7s_blank_fadeblack.mp4` — 7s logo intro with a black fade-out.
- `input.*` — source recording in multiple formats.
- `transcript/` — Whisper-style transcripts of `input` in several formats:
  - `input.json` — segments with timestamps and metadata
  - `input.srt` / `input.vtt` — subtitle formats
  - `input.tsv` — tab-separated start/end/text
  - `input.txt` — plain text transcript

## Note on media files

The large media files (`*.mp4`, `*.webm`, `*.wav`, `*.mp3`, …) are **gitignored**
because they exceed GitHub's 100MB per-file limit. Only the text transcripts are
tracked in this repo. Store the binaries in object storage or Git LFS if they need
to be versioned.

## License

[MIT](LICENSE) © 2026 Profullstack, Inc.
