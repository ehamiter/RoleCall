<div align="center">
  <img src="RoleCall/Assets.xcassets/AppIcon.appiconset/1024.png" alt="RoleCall" width="200"/>
</div>

# RoleCall

An iOS app that connects to your Plex Media Server to browse active sessions and view detailed cast information using IMDb.

## Features

- **OAuth Login**: Secure authentication via Plex.tv with MFA support
- **Demo Mode**: Built-in demo account for app reviewers
- **Active Sessions**: View current video playback sessions on your Plex server
- **Cast Details**: Browse movie cast and crew with IMDb integration
- **Actor Profiles**: View biographies, photos, and filmographies
- **Server Info**: View Plex server capabilities and status

## Setup

1. Enter your Plex Media Server IP address in Settings
2. Tap "Login with Plex" to authenticate via Plex.tv
3. Browse active sessions and tap any movie to view cast details

That's it! No API keys required.

## Demo Mode

For app reviewers: tap "App Review? Use Demo Account" on the login screen to access demo mode without a Plex server.

## Requirements

- iOS 15.0+
- Xcode 16.0+
- Swift 5.0+
- Plex Media Server with network access
- Valid Plex account

## Building

Open `RoleCall.xcodeproj` in Xcode and build normally. No additional configuration required.

```bash
# Simulator
xcodebuild -project "RoleCall.xcodeproj" -scheme "RoleCall" \
  -destination 'generic/platform=iOS Simulator,name=iPhone 16' build

# Device
xcodebuild -project "RoleCall.xcodeproj" -scheme "RoleCall" \
  -destination 'generic/platform=iOS' build
```

## API Endpoints

### Plex
- `POST https://plex.tv/api/v2/pins` - OAuth PIN generation
- `GET https://plex.tv/api/v2/pins/{pinId}` - OAuth polling
- `GET http://{server}:32400/?X-Plex-Token={token}` - Server capabilities
- `GET http://{server}:32400/status/sessions?X-Plex-Token={token}` - Active sessions
- `GET http://{server}:32400/library/metadata/{id}?X-Plex-Token={token}` - Movie metadata

### IMDb (api.imdbapi.dev)
- `GET /names/{nameId}` - Actor information
- `GET /names/{nameId}/filmography` - Actor filmography
- `GET /titles/{titleId}` - Movie details
- `GET /titles/{titleId}/credits` - Movie cast and crew
- `GET /search/titles` - Movie search

No API key required for IMDb - uses free public API.

## License

See [LICENSE](LICENSE) for details.
