# macOS Buzzkill

Workaround for the USB audio buffer-loop buzz introduced on macOS Tahoe (26.x)
and persisting on macOS Golden Gate (27.x) for class-compliant audio interfaces.
In my case, the Allen & Heath CQ-18T connected via USB.

## The problem

Since macOS Tahoe, when an app stops or tears down audio playback abruptly
(closing a tab or app without pressing stop, scrubbing the timeline), some
class-compliant USB interfaces loop their last USB buffer indefinitely,
producing a loud buzz or beep that continues until new audio plays or the cable
is re-plugged. For my experience, see the [Allen & Heath forum thread]. As of
October 2026 there is no fix from Apple or Allen & Heath.

## The workaround

`buzzkilld` is a tiny daemon that holds the system default audio output stream
permanently open by rendering silence through a CoreAudio DefaultOutput unit.
Because the output stream never tears down, the bug never triggers.

- Output-only: never records audio
- Follows the system default output device automatically
- Renders zeros; negligible CPU, truly silent

## Install

```sh
brew install cavaliercoder/tap/buzzkill
brew services start buzzkill
```

The service starts at login and restarts if it exits.

macOS may ask to allow microphone access for `buzzkilld` when the service first
starts, even though it only plays output (seen with a duplex USB interface).
Choose Don't Allow; silence keeps playing either way.

## Uninstall

```sh
brew services stop buzzkill
brew uninstall buzzkill
```

## Manual install (without Homebrew)

Requires the Xcode Command Line Tools (`xcode-select --install`):

```sh
make            # swift build -c release
make test       # unit tests
make smoke      # end-to-end smoke test (starts and stops the daemon)
sudo make install   # installs /usr/local/bin/buzzkilld
```

Then run `buzzkilld` from a login item or your own LaunchAgent.

## License

MIT

[Allen & Heath forum thread]:
  https://forums.allen-heath.com/t/noise-issue-with-cq-18t-after-upgrading-to-macos-26/30398/4
