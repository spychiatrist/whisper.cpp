# whisper-paste

local, offline voice-to-text that pastes straight into whatever you're typing in. works in browsers, messages, slack, terminals, everywhere. no cloud, no subscription, no latency waiting on an API.

runs [whisper.cpp](https://github.com/ggml-org/whisper.cpp) locally on Apple Silicon via Metal — on an M1 Max it's fast enough that you don't really notice the transcription step.

## requirements

- Apple Silicon Mac (M1/M2/M3/M4)
- macOS 13+
- [Homebrew](https://brew.sh)

## install

clone this repo (or your fork of it), then run:

```bash
./tools/whisper-paste/install.sh
```

that's it. the script handles everything — dependencies, building whisper.cpp with Metal, downloading the model, dropping the script in `~/.local/bin`, and setting up the global hotkey via [skhd](https://github.com/koekeishiya/skhd).

two things you'll need to grant manually after (macOS won't let a script do these):

1. **Microphone** — System Settings → Privacy & Security → Microphone → enable Terminal (or whatever app you trigger the hotkey from)
2. **Accessibility** — System Settings → Privacy & Security → Accessibility → add `/opt/homebrew/Cellar/skhd/<version>/bin/skhd` (use the real binary path, not the symlink at `/opt/homebrew/bin/skhd`)

restart skhd after granting accessibility:
```bash
skhd --restart-service
```

## usage

**record hotkey:** `⌥⌘Space` — works anywhere, including terminals, iMessage, Slack, browsers
**settings hotkey:** `⌥⌘,` — opens the settings menu (macOS preference convention)

1. press `⌥⌘Space`; you'll hear a Tink sound confirming it started
2. speak — pause as long as you like, it won't cut you off (default 30 min timeout)
3. click **Normal** or **casual** to stop and transcribe; **Cancel** (or Escape) to abort

the transcribed text is copied to your clipboard and pasted into whatever field was focused when you triggered the hotkey.

if the recording times out, you'll hear a Basso sound and the audio is transcribed anyway (no work lost).

you can also run it directly from a terminal:

```bash
whisper-paste              # record
whisper-paste --settings   # open settings menu
whisper-paste --retry      # re-transcribe the last recording with jittered params
whisper-paste --last       # copy the last transcript to the clipboard again
whisper-paste --dir        # print the last recording's folder
```

## recordings and retry

every recording is kept, including cancelled ones, under `~/.local/share/blather/recordings/<timestamp>/`:

- `audio.wav`: the raw 16kHz mono recording, written there live so a crash mid-recording doesn't lose it
- `transcript.txt`: what got pasted
- `whisper.json`: whisper-cli's full JSON output (segments, tokens, probabilities)
- `meta.json`: style, status (`ok`, `cancelled`, `empty`, or `transcribing` if whisper died), frontmost app, duration, timings

if a transcription comes back garbled (repetition loops, dropped sentences), run `whisper-paste --retry` or pick **Retry Last Recording** in settings. each retry shifts the 30s decode windows with a random 50-450ms lead-in of silence, turns on VAD, drops prior-text conditioning (the main repetition-loop trigger), and nudges the base temperature up 0.1 per attempt. results land in `retries/N.txt` with their params in `retries/N.json` and are copied to the clipboard.

nothing is deleted automatically; audio costs about 2MB per minute.

## settings

press `⌥⌘,` (or run `whisper-paste --settings`) to open a menu with:

- **Change Timeout** — how long the recording dialog waits before auto-transcribing (default 30 min)
- **Change Default Style** — Normal or casual (controls which button is selected when you press Return)
- **Edit Casual Prompt** — opens `casual.txt` in your default text editor
- **Retry Last Recording** — see [recordings and retry](#recordings-and-retry)
- **Open Recordings Folder** — opens `~/.local/share/blather/recordings` in Finder

settings are stored in `~/.config/whisper-dictate/config` as `KEY=VALUE` pairs.

## style modes

**Normal** — straight whisper output, no style priming. accurate, properly capitalised, great for most things.

**casual** — uses an initial prompt to nudge the output toward a more conversational register. edit `~/.config/whisper-dictate/styles/casual.txt` to match how you actually write; the install script drops an example there to start from. whisper uses it as previous-transcript context (not instructions), so writing the prompt *in your actual style* works better than describing rules.

note: casual mode can occasionally hallucinate on silence or very short recordings — just hit Cancel or Escape if you trigger it accidentally.

## configuration

settings live in `~/.config/whisper-dictate/config` (managed via the settings menu). environment variables override at runtime:

| env var | default | description |
|---|---|---|
| `WHISPER_DIR` | set by install script | path to the whisper.cpp repo root |
| `WHISPER_CLI` | `$WHISPER_DIR/build/bin/whisper-cli` | override the binary |
| `WHISPER_MODEL` | `$WHISPER_DIR/models/ggml-large-v3-turbo.bin` | use a different model |
| `WHISPER_STYLE_DIR` | `~/.config/whisper-dictate/styles` | directory containing style prompt files |
| `WHISPER_TIMEOUT` | `1800` (30 min) | recording dialog timeout in seconds |
| `WHISPER_DEFAULT_STYLE` | `Normal` | default button (`Normal` or `casual`) |
| `WHISPER_LOG_DIR` | `~/.local/share/blather/recordings` | where recordings are kept |
| `WHISPER_VAD_MODEL` | `$WHISPER_DIR/models/ggml-silero-v6.2.0.bin` | VAD model used by `--retry` (skipped if missing; fetch with `models/download-vad-model.sh silero-v6.2.0`) |

## development

if you're hacking on the script:

```bash
./tools/whisper-paste/test-whisper-paste   # run the test suite (mocks all deps)
./tools/whisper-paste/deploy               # test, then copy to ~/.local/bin
```

the test suite mocks `osascript`, `rec`, `sox`, `whisper-cli`, `pbcopy`, etc. so it runs anywhere without a mic or whisper install. it covers the main flows (normal, casual, cancel, timeout), the recording log, and `--retry` / `--last`.

## model

defaults to `large-v3-turbo` (~800MB). fast on Apple Silicon; on an M1 Max a 30-second recording transcribes in a couple seconds. if you want to try a different model:

```bash
bash models/download-ggml-model.sh large-v3   # higher accuracy, slower
bash models/download-ggml-model.sh base.en     # much smaller, much faster, English only
```

then set `WHISPER_MODEL` to point at it.

## customising your casual style

open `~/.config/whisper-dictate/styles/casual.txt` and replace the example with how you actually text. the more representative the better — whisper treats it as a previous transcript and tries to continue in the same register. a few sentences in your real voice beats any amount of instruction text.
