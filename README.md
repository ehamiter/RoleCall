# RoleCall - Plex Integration App

An iOS SwiftUI app that connects to a Plex Media Server to interact with your media library and provides detailed cast information using a free IMDb API.

## Features

### ✅ Current Implementation

- **Server Configuration**: Set your Plex Media Server IP address in settings
- **Authentication**: Login with your Plex username/email and password
- **Token Management**: Automatically stores and manages X-Plex-Token for API access
- **Token Validation**: Checks token validity on app launch and refreshes as needed
- **Server Capabilities**: View detailed information about your Plex server's capabilities and features
- **Active Sessions**: View current video sessions on your Plex server
- **Movie Details**: Rich movie information including poster, summary, cast, and crew
- **Cast Member Details**: Tap any cast member to view detailed actor information from IMDb
- **Actor Profiles**: See actor biographies, photos, and filmographies

### 🎬 IMDb Integration

The app integrates with a free IMDb API to provide enhanced cast and crew information:

- **Actor Search**: Automatically searches IMDb for cast members by name
- **Detailed Profiles**: Biography, birthplace, birth/death years, and career information
- **High-Quality Photos**: Professional actor headshots and photos
- **Filmography**: Complete list of movies and TV shows the actor has appeared in
- **IMDb Ratings**: Authoritative movie ratings and vote counts
- **No API Key Required**: Uses a free, public IMDb API service

### 🔧 Simple Setup

The app requires minimal configuration - no API keys needed:

1. **Plex Server Setup**:
   - Enter your Plex Media Server IP address in app settings
   - Login with your Plex credentials

That's it! The app uses a free IMDb API service that doesn't require registration or API keys.

### 🔧 Settings

1. **Configure Server IP**: Enter your Plex Media Server IP address (e.g., 192.168.1.100)
2. **Save Settings**: Store your configuration for future use
3. **Logout**: Clear stored credentials and tokens

### 🔐 Authentication Flow

1. **Login Form**: Enter your Plex account credentials (username/email and password)
2. **Token Exchange**: App exchanges credentials for an X-Plex-Token with plex.tv API
3. **Token Storage**: Securely stores the token locally with expiration tracking
4. **Auto-Login**: On subsequent launches, checks if stored token is still valid

### 📊 Server Capabilities

The app fetches and displays comprehensive server information including:

- **Server Information**: Name, version, platform details
- **MyPlex Integration**: Account status, subscription info
- **Media Capabilities**: Transcoding support, library features
- **Technical Details**: Platform version, machine identifier
- **Raw JSON**: View the complete API response

## API Endpoints Used

### Plex Authentication
- `POST https://plex.tv/users/sign_in.json` - User login and token exchange

### Plex Server API
- `GET http://{ip_address}:32400/?X-Plex-Token={plex_token}` - Server capabilities and information
- `GET http://{ip_address}:32400/status/sessions?X-Plex-Token={plex_token}` - Active playback sessions
- `GET http://{ip_address}:32400/library/metadata/{id}?X-Plex-Token={plex_token}` - Movie metadata and cast information

### IMDb API (rest.imdbapi.dev)
- `GET https://rest.imdbapi.dev/v2/names/{nameID}` - Get detailed actor information
- `GET https://rest.imdbapi.dev/v2/names/{nameID}/known_for` - Get actor's filmography
- `GET https://rest.imdbapi.dev/v2/titles/{titleID}/credits` - Get movie cast and crew
- `GET https://rest.imdbapi.dev/v2/search/titles?q={query}` - Search for movies/shows

## No Configuration Required

### API Key-Free Architecture

This app uses a free, public IMDb API service that eliminates the need for API key management:

1. **No Registration**: No need to sign up for API access
2. **No Keys to Manage**: No API keys, tokens, or credentials required for movie data
3. **No Rate Limits**: Reasonable usage without strict rate limiting
4. **Simplified Deployment**: No configuration files or secrets to manage

The only credentials needed are your Plex server access (IP address and your existing Plex account).

## Technical Details

### Architecture
- **SwiftUI**: Modern declarative UI framework
- **MVVM Pattern**: Clean separation of concerns
- **ObservableObject**: Reactive state management
- **UserDefaults**: Local storage for settings and tokens
- **URLSession**: HTTP networking for API calls

### Security
- Secure token storage using UserDefaults
- Token expiration tracking (30-day default)
- Automatic token validation on app launch
- Sensitive data clearing on logout

### Error Handling
- Network connectivity issues
- Invalid credentials
- Server unreachable
- Token expiration
- Malformed responses

## Usage

1. **First Time Setup**:
   - Tap the gear icon to open Settings
   - Enter your Plex Media Server IP address
   - Save settings
   - Return to main screen and enter your Plex credentials
   - Tap Login
   - No additional API setup required!

2. **Viewing Server Info**:
   - Once logged in, the app displays server capabilities
   - Tap "Refresh" to reload server information
   - Navigate through different sections to explore server features
   - View raw JSON response for technical details

3. **Managing Authentication**:
   - Settings shows connection status when logged in
   - Use "Logout" in settings to clear credentials
   - App automatically attempts re-authentication if token expires

## Requirements

- iOS 18.5+
- Xcode 16.0+
- Swift 5.0+
- Plex Media Server with network access
- Valid Plex account credentials

## Building

### Building the Project

Simply build the project with Xcode - no additional configuration required:

```bash
# For Simulator
xcodebuild -project "RoleCall.xcodeproj" -scheme "RoleCall" -destination 'generic/platform=iOS Simulator,name=iPhone 16' build

# For Device
xcodebuild -project "RoleCall.xcodeproj" -scheme "RoleCall" -destination 'generic/platform=iOS' build
```

Or simply open `RoleCall.xcodeproj` in Xcode and build normally.

✅ **Note**: The app builds and runs immediately without any additional setup - no API keys or configuration files required.

## Future Enhancements

Potential features for future development:
- Media library browsing
- Playback controls
- Search functionality
- Recently added media
- User management
- Playlist creation and management
- Download capabilities
- Offline viewing support

## API Reference

For complete Plex API documentation, see the included reference materials in the `reference/` directory.
