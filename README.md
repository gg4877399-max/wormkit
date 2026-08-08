# WormKit

**WormGPT AI Assistant - Android App**

A Kivy-based Android chat application that connects to the WormGPT AI backend.

## Installation

1. Go to [Releases](https://github.com/gg4877399-max/wormkit/releases)
2. Download the latest APK
3. Open on your Android device (enable "Install from unknown sources" if prompted)

## Build from Source

```bash
git clone https://github.com/gg4877399-max/wormkit.git
cd wormkit
pip install buildozer
buildozer android debug
```

The GitHub Actions workflow will also build the APK automatically on every push.

## API Endpoint

The app connects to: `https://wormgpt-api.onrender.com/chat`

## License

MIT
