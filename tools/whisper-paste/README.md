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

**hotkey:** `⌥⌘Space` — works anywhere, including terminals, iMessage, Slack, browsers

1. press `⌥⌘Space`; you'll hear a Tink sound confirming it started
2. speak — pause as long as you like, it won't cut you off
3. click **Normal** or **casual** to stop and transcribe; **Cancel** (or Escape) to abort

the transcribed text is copied to your clipboard and pasted into whatever field was focused when you triggered the hotkey.

you can also run it directly from a terminal:

```bash
whisper-paste
```

## style modes

**Normal** — straight whisper output, no style priming. accurate, properly capitalised, great for most things.

**casual** — uses an initial prompt to nudge the output toward a more conversational register. edit `~/.config/whisper-dictate/styles/casual.txt` to match how you actually write; the install script drops an example there to start from. whisper uses it as previous-transcript context (not instructions), so writing the prompt *in your actual style* works better than describing rules.

note: casual mode can occasionally hallucinate on silence or very short recordings — just hit Cancel or Escape if you trigger it accidentally.

## configuration

| env var | default | description |
|---|---|---|
| `WHISPER_DIR` | set by install script | path to the whisper.cpp repo root |
| `WHISPER_CLI` | `$WHISPER_DIR/build/bin/whisper-cli` | override the binary |
| `WHISPER_MODEL` | `$WHISPER_DIR/models/ggml-large-v3-turbo.bin` | use a different model |
| `WHISPER_STYLE_DIR` | `~/.config/whisper-dictate/styles` | directory containing style prompt files |

## model

defaults to `large-v3-turbo` (~800MB). fast on Apple Silicon; on an M1 Max a 30-second recording transcribes in a couple seconds. if you want to try a different model:

```bash
bash models/download-ggml-model.sh large-v3   # higher accuracy, slower
bash models/download-ggml-model.sh base.en     # much smaller, much faster, English only
```

then set `WHISPER_MODEL` to point at it.

## customising your casual style

open `~/.config/whisper-dictate/styles/casual.txt` and replace the example with how you actually text. the more representative the better — whisper treats it as a previous transcript and tries to continue in the same register. a few sentences in your real voice beats any amount of instruction text.
