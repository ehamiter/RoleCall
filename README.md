# RoleCall - Plex Integration App

An iOS SwiftUI app that connects to a Plex Media Server to interact with your media library.

## Features

### ✅ Current Implementation

- **Server Configuration**: Set your Plex Media Server IP address in settings
- **Authentication**: Login with your Plex username/email and password
- **Token Management**: Automatically stores and manages X-Plex-Token for API access
- **Token Validation**: Checks token validity on app launch and refreshes as needed
- **Server Capabilities**: View detailed information about your Plex server's capabilities and features

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

### Authentication
- `POST https://plex.tv/users/sign_in.json` - User login and token exchange

### Server Capabilities
- `GET http://{ip_address}:32400/?X-Plex-Token={plex_token}` - Server capabilities and information

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

To build the project:

```bash
xcodebuild -project "RoleCall.xcodeproj" -scheme "RoleCall" -destination 'generic/platform=iOS Simulator,name=iPhone 16' build
```

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
