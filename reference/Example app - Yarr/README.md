# Yarr

### YIFY API Record Retriver
[![Platform](https://img.shields.io/badge/platform-macOS-blue.svg)](https://www.apple.com/macos/)
[![Language](https://img.shields.io/badge/language-Swift-orange.svg)](https://swift.org/)
[![UI Framework](https://img.shields.io/badge/UI-SwiftUI-green.svg)](https://developer.apple.com/xcode/swiftui/)


<div align="center">
  <img src="./yarr.png" alt="Yarr App Icon" width="400" height="400" />
  <br>
  <em>Shiver B. Timbers, <strong>Yarr</strong>'s official esteemed anthropomorphic logo</em>
  <br>
  <sub></sub>
</div>
<br>

**Yarr** (YIFY API Record Retriever) is a native macOS application for discovering and remotely downloading torrents through the YTS (YIFY) API. Built with SwiftUI, it provides a modern, intuitive interface for browsing movies and automatically transferring torrent files to remote servers via SSH.

## 🎯 Overview

Yarr bridges the gap between movie discovery and remote torrent management. Instead of manually searching for torrents and transferring files, Yarr streamlines the entire process into a few clicks. Browse thousands of movies, apply sophisticated filters, and send torrents directly to your remote download server.

## ✨ Features

### 🎬 Movie Discovery
- **Comprehensive Search**: Search by title, director, actor, or IMDb code
- **Advanced Filtering**: Filter by quality (480p to 4K), genre, rating, year, and more
- **Smart Sorting**: Sort by title, year, rating, seeds, peers, download count, likes, or date added
- **Detailed Information**: View full movie details, cast, ratings, and screenshots
- **Related Movies**: Discover similar movies through intelligent recommendations

### 📱 Modern Interface
- **Native macOS Design**: Built with SwiftUI for optimal performance and native feel
- **Responsive Grid Layout**: Adaptive movie grid that scales with window size
- **Rich Movie Cards**: Beautiful cards with cover art, ratings, and key information
- **Detailed Views**: Full-screen movie details with comprehensive information
- **Dark/Light Mode**: Automatic support for system appearance preferences

### ⚡ Performance & Caching
- **Intelligent Caching**: Multi-level caching for API responses and images
- **Configurable Cache**: Customizable cache timeouts and size limits
- **Lazy Loading**: Efficient image loading with memory management
- **Pagination**: Seamless infinite scrolling for large result sets

### 🌐 Remote Integration
- **SSH Transfer**: Secure file transfer to remote torrent clients
- **Automatic Downloads**: One-click torrent file transfer to watch directories
- **Connection Testing**: Built-in SSH connection validation
- **Flexible Configuration**: Support for custom SSH ports and paths

### 🔧 Advanced Configuration
- **Quality Preferences**: Set preferred download qualities
- **Cache Management**: Fine-tune caching behavior and storage limits
- **Network Settings**: Configure timeouts and connection parameters
- **Security**: Encrypted credential storage using macOS Keychain

## 🏗️ System Architecture

### Core Components

#### **API Layer**
- `MovieAPIService`: Manages all YTS API interactions with intelligent caching
- `ImageCacheService`: Handles efficient image downloading and storage
- `Models.swift`: Comprehensive data models for API responses

#### **User Interface**
- `ContentView`: Main application interface with search and filtering
- `MovieDetailsView`: Detailed movie information and torrent management
- `MovieCardView`: Reusable movie display component
- `SettingsView`: Configuration and preferences management

#### **Services**
- `RemoteDownloadService`: SSH-based torrent file transfer
- `MovieViewModel`: Business logic and state management
- `SettingsModel`: Application configuration and user preferences

### Data Flow

```
User Input → MovieViewModel → MovieAPIService → YTS API
                ↓
Movie Data → UI Components → User Selection → RemoteDownloadService → SSH Transfer
```

### Caching Strategy

1. **API Response Caching**: In-memory caching with configurable timeouts
2. **Image Caching**: Disk-based caching with automatic cleanup
3. **HTTP Caching**: URLSession-level caching for network efficiency

## 🚀 Getting Started

### Prerequisites

- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.0+**
- **SSH access** to a remote server (for torrent transfers)
- **Active internet connection**

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/yarr.git
   cd yarr
   ```

2. **Open in Xcode**
   ```bash
   open yarr.xcodeproj
   ```

3. **Build and run**
   - Select your target device/simulator
   - Press `Cmd + R` to build and run

### Configuration

1. **Launch Yarr** and open Settings (⌘,)

2. **Configure SSH Connection**
   - Username: Your SSH username
   - Hostname: Your server's hostname or IP
   - Port: SSH port (default: 22)
   - Watch Directory: Path where torrents should be uploaded

3. **Test Connection** to verify SSH setup

4. **Configure Caching** (optional)
   - Enable/disable image and API caching
   - Set cache expiration times
   - Adjust cache size limits

## 🎮 Usage

### Basic Workflow

1. **Browse Movies**: Use the main interface to explore available movies
2. **Apply Filters**: Narrow results by quality, genre, rating, etc.
3. **View Details**: Click any movie for detailed information
4. **Download Torrents**: Select quality and click "Download" to transfer to remote server

### Search Tips

- **Exact Matches**: Use quotes for exact title matches
- **Flexible Search**: Search works with partial titles, actors, or directors
- **IMDb Integration**: Use IMDb codes for precise movie identification

### Filter Combinations

- Combine multiple filters for precise results
- Use quality filters to match your bandwidth/storage needs
- Rating filters help find higher-quality content
- Genre filters perfect for browsing specific moods

## 🔧 Configuration Options

### SSH Settings
- **Custom Ports**: Support for non-standard SSH ports
- **Key-based Authentication**: Uses system SSH configuration
- **Path Validation**: Ensures remote directories are accessible

### Cache Settings
- **API Cache**: 5-60 minutes (default: 15 minutes)
- **Image Cache**: 1-30 days (default: 7 days)
- **Cache Size**: Configurable memory and disk limits

### Performance Tuning
- **Connection Limits**: Optimize concurrent downloads
- **Timeout Settings**: Adjust for slower connections
- **Retry Logic**: Automatic retry on failed requests

## 🛠️ Development

### Project Structure

```
yarr/
├── yarrApp.swift           # Application entry point
├── Models.swift            # Data models and API responses
├── MovieAPIService.swift   # YTS API integration
├── ContentView.swift       # Main application interface
├── MovieDetailsView.swift  # Detailed movie view
├── MovieCardView.swift     # Movie display component
├── SettingsView.swift      # Configuration interface
├── RemoteDownloadService.swift # SSH transfer service
├── ImageCacheService.swift # Image caching system
├── CachedAsyncImage.swift  # Async image loading
├── MovieViewModel.swift    # Business logic
└── SettingsModel.swift     # Configuration management
```

### Key Technologies

- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for data flow
- **URLSession**: Network requests with caching
- **Foundation**: Core system integration
- **Security**: Keychain for credential storage

### API Integration

Yarr integrates with the YTS (YIFY) API:
- **Base URL**: `https://yts.mx/api/v2/`
- **Endpoints**: `list_movies.json`, `movie_details.json`, `movie_suggestions.json`
- **Rate Limiting**: Intelligent request throttling
- **Error Handling**: Comprehensive error management

## 🔒 Security & Privacy

- **Local Storage**: All credentials stored in macOS Keychain
- **SSH Security**: Uses system SSH configuration and keys  
- **No Data Collection**: No analytics or user data transmission
- **API Compliance**: Respects YTS API terms and rate limits

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Swift style conventions
- Add unit tests for new functionality
- Update documentation for API changes
- Test on multiple macOS versions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

Yarr is a tool for managing legitimate torrent files. Users are responsible for ensuring their downloads comply with local laws and respect copyright. The developers are not responsible for any misuse of this software.

## 🙏 Acknowledgments

- **YTS (YIFY)** for providing the movie API
- **Apple** for SwiftUI and the macOS development platform
- **Open Source Community** for inspiration and best practices

---

**Built with ❤️ for the macOS community**
