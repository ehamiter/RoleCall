# RoleCall - Plex Integration App

An iOS SwiftUI app that connects to a Plex Media Server to interact with your media library and provides detailed cast information using TMDB integration.

## Features

### ✅ Current Implementation

- **Server Configuration**: Set your Plex Media Server IP address in settings
- **Authentication**: Login with your Plex username/email and password
- **Token Management**: Automatically stores and manages X-Plex-Token for API access
- **Token Validation**: Checks token validity on app launch and refreshes as needed
- **Server Capabilities**: View detailed information about your Plex server's capabilities and features
- **Active Sessions**: View current video sessions on your Plex server
- **Movie Details**: Rich movie information including poster, summary, cast, and crew
- **Cast Member Details**: Tap any cast member to view detailed actor information from TMDB
- **Actor Profiles**: See actor biographies, photos, and filmographies

### 🎬 TMDB Integration

The app integrates with The Movie Database (TMDB) to provide enhanced cast and crew information:

- **Actor Search**: Automatically searches TMDB for cast members
- **Detailed Profiles**: Biography, birthplace, known for department
- **High-Quality Photos**: Professional actor headshots and photos
- **Filmography**: Complete list of movies and TV shows the actor has appeared in
- **Ratings**: Movie ratings and popularity scores

### 🔧 Configuration Setup

Before running the app, you need to configure API keys:

1. **Copy Configuration Template**:
   ```bash
   cp Config.template.plist RoleCall/Config.plist
   ```

2. **Get TMDB API Keys**:
   - Visit [TMDB API](https://www.themoviedb.org/settings/api)
   - Sign up for a free account
   - Request API access
   - Copy your API Key and Read Access Token

3. **Update Config.plist**:
   ```xml
   <key>TMDB_API_KEY</key>
   <string>your_tmdb_api_key_here</string>
   <key>TMDB_ACCESS_TOKEN</key>
   <string>your_tmdb_access_token_here</string>
   ```

4. **Plex Server Setup**:
   - Enter your Plex Media Server IP address in app settings
   - Login with your Plex credentials

⚠️ **Important**: Never commit your actual `Config.plist` file with real API keys to version control. The file is already included in `.gitignore`.

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

### TMDB API
- `GET https://api.themoviedb.org/3/search/person` - Search for actors by name
- `GET https://api.themoviedb.org/3/person/{id}` - Get detailed actor information
- `GET https://api.themoviedb.org/3/person/{id}/movie_credits` - Get actor's filmography

## Configuration Security

### iOS/Swift API Key Management

Unlike server-side applications that can use environment variables, iOS apps require a different approach for managing API keys:

1. **Configuration Files**: We use `Config.plist` files to store API keys
2. **Version Control Exclusion**: The actual config file is gitignored
3. **Template System**: A template file shows the required structure
4. **Build-time Integration**: Keys are bundled with the app during build

This approach is suitable for public APIs like TMDB where the keys will be included in the distributed app. For more sensitive keys, consider:
- Server-side proxy endpoints
- Key obfuscation techniques
- Runtime key fetching from secure servers

### Why Not Environment Variables?

Environment variables work great for server applications (Python, Node.js, etc.) but don't translate directly to iOS apps because:
- iOS apps run in sandboxed environments
- No shell environment during runtime
- Configuration must be bundled at build time
- Apps are distributed as static binaries

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

### Prerequisites

1. **Create Configuration File**:
   ```bash
   cp Config.template.plist RoleCall/Config.plist
   ```

2. **Add Your API Keys** to `RoleCall/Config.plist`:
   - Get TMDB API keys from [themoviedb.org](https://www.themoviedb.org/settings/api)
   - Replace placeholder values with your actual keys

3. **Build the Project**:
   ```bash
   # For Simulator
   xcodebuild -project "RoleCall.xcodeproj" -scheme "RoleCall" -destination 'generic/platform=iOS Simulator,name=iPhone 16' build
   
   # For Device
   xcodebuild -project "RoleCall.xcodeproj" -scheme "RoleCall" -destination 'generic/platform=iOS' build
   ```

   Or simply open `RoleCall.xcodeproj` in Xcode and build normally.

⚠️ **Note**: The app will not build or function properly without a valid `Config.plist` file containing TMDB API keys.

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
