# ReadGood - Native macOS News Aggregator

A native macOS rewrite of BOBrowser, providing a clean menu bar interface for aggregating and reading stories from Hacker News, Reddit, and Pinboard.


![Screenshot 2025-06-04 at 3 02 17 PM](https://github.com/user-attachments/assets/61ef931c-3689-4d05-9e0b-daece3741b26)

> **Status**: ✅ **First working build complete!** The app now compiles and runs successfully as a native macOS menu bar application.

## Features

### 📰 Multi-Source Aggregation
- **Hacker News**: Top stories via Firebase API
- **Reddit**: Configurable subreddits via OAuth API  
- **Pinboard**: Popular bookmarks via web scraping

### 🎯 One-Click Reading
Single click on any story automatically:
- Archives content via archive.ph
- Opens comments/discussion page
- Opens original article (becomes active tab)
- Auto-generates AI tags using Claude CLI

### 🏷️ AI-Powered Tagging
- Integrates with Claude CLI for intelligent content categorization
- Automatically applies tags when articles are clicked
- Manual tag management and search capabilities

### 📊 Comprehensive Tracking
- **Core Data** database tracks all interactions
- Monitors story appearances vs actual clicks
- Tracks reading patterns and engagement metrics
- Archives URLs for offline access

### 🔍 Advanced Features
- Tag-based search across all tracked content
- Database browser with filtering (Gems, Unread, Recent, All)
- Full-text search for saved articles
- Native macOS menu bar integration

## Technology Stack

- **Swift/SwiftUI** for UI and app logic
- **Core Data** for persistent storage
- **URLSession** for HTTP requests
- **NSStatusItem** for menu bar integration
- **Claude CLI** for AI-powered tagging

## Installation

### Prerequisites
- macOS 13.0 or later
- Xcode 15+ (for building from source)
- Claude CLI (for AI tagging) - [Download here](https://www.anthropic.com/claude-code)

### Building from Source
```bash
# Clone the repository
git clone [repository-url]
cd read_good

# Open in Xcode
open ReadGood.xcodeproj

# Set your development team in Xcode:
# 1. Select ReadGood project in sidebar
# 2. Go to Signing & Capabilities tab
# 3. Choose your Apple ID from Team dropdown

# Build and run (⌘+R)
```

### Quick Start
```bash
# 1. Build and run in Xcode (⌘+R)
# 2. Look for document icon in menu bar
# 3. Click icon to see story popover
# 4. Click any story to read!
```

### First Run
When you first run the app:
1. **Menu bar icon** appears (document icon in top-right menu bar)
2. **Click the icon** to see the story aggregator popover  
3. **Stories load automatically** from Hacker News and Pinboard (Reddit requires setup)
4. **Click any story** to automatically:
   - Archive the content via archive.ph
   - Open discussion/comments page
   - Open the original article
   - Generate AI tags (if Claude CLI available)

### Environment Setup

For Reddit integration, set environment variables:
```bash
export REDDIT_CLIENT_ID="your_client_id"
export REDDIT_CLIENT_SECRET="your_client_secret"
```

Or configure via the Settings window after first launch.

## Current Implementation Status

### ✅ What's Working
- **Menu bar integration**: Native NSStatusItem with document icon
- **Story aggregation**: Successfully fetches from all three sources
  - Hacker News: Top stories via Firebase API
  - Reddit: Configurable subreddits via OAuth (requires API credentials)
  - Pinboard: Popular bookmarks via web scraping
- **Story display**: Clean SwiftUI popover with source indicators (🟠 📌 👽)
- **Link opening**: One-click opens archive + comments + article in sequence
- **Core Data**: Full database tracking of stories, clicks, and engagement
- **Archive integration**: Automatic archive.ph submission and access
- **Claude CLI integration**: AI tagging when Claude is available in PATH
- **Settings interface**: Configuration for Reddit credentials and preferences

### 🚧 Known Issues
- **Reddit authentication**: Requires manual API credential setup
- **Claude dependency**: Falls back gracefully when Claude CLI unavailable
- **Story filtering**: Database browser filters (Gems, Recent, etc.) need Core Data integration
- **Notification system**: Permission requested but not yet implemented

### 🔄 Next Steps
- Implement Core Data fetching for filtered views
- Add notification system for interesting stories
- Enhanced tag management interface
- Export/import functionality for story database
- App Store distribution preparation

## Architecture

### Core Components

#### 📱 App Structure
- `ReadGoodApp.swift` - Main app entry point with NSApplicationDelegate
- `StatusBarController.swift` - Menu bar icon and popover management
- `StoryManager.swift` - Central coordinator for story fetching and user interactions

#### 🗄️ Data Layer
- **Core Data Models**: `Story`, `Tag`, `Click` entities
- **DataController**: Core Data stack management and operations
- **API Services**: Separate clients for HN, Reddit, and Pinboard

#### 🎨 UI Layer
- **StoryMenuView**: Main popover interface showing aggregated stories
- **SettingsView**: Configuration interface for API credentials and preferences
- **SwiftUI + AppKit**: Native macOS UI with menu bar integration

#### 🔧 Services
- **ClaudeService**: Claude CLI integration for AI tagging
- **ArchiveService**: archive.ph URL generation and management
- **Individual APIs**: HackerNewsAPI, RedditAPI, PinboardAPI

## Configuration

### Reddit Setup
1. Go to [reddit.com/prefs/apps](https://www.reddit.com/prefs/apps)
2. Create a new "Script" application
3. Note your Client ID and Secret
4. Configure in Settings or set environment variables

### Claude Integration
1. Install Claude CLI from [claude.ai/download](https://claude.ai/download)
2. Ensure `claude` command is available in PATH
3. ReadGood will automatically detect and use Claude for tagging

## Usage

### Basic Operation
1. **Click the menu bar icon** to see aggregated stories
2. **Click any story** to automatically open archive + comments + article
3. **Use Settings** to configure Reddit credentials and subreddit preferences
4. **Search and filter** stories using the built-in database browser

### Menu Bar App
- Lives in your menu bar, no dock icon
- Stories refresh automatically every 5 minutes
- Unobtrusive notification system for new interesting stories

## Migration from Electron Version

This native version maintains feature parity with the original Electron BOBrowser:

### ✅ Implemented Features
- Multi-source story aggregation (HN, Reddit, Pinboard)
- Menu bar interface with story display
- One-click article opening with archive integration
- Claude CLI integration for AI tagging
- Core Data database for comprehensive tracking
- Settings interface for configuration

### 🔄 Architecture Improvements
- **Native Performance**: SwiftUI + Core Data vs Electron + SQLite
- **Better macOS Integration**: NSStatusItem, native notifications, proper settings
- **Memory Efficiency**: Native Swift vs Chromium overhead
- **System Integration**: Uses macOS keychain, appearance settings, etc.

## Development

### Project Structure
```
ReadGood/
├── ReadGoodApp.swift           # App entry point
├── StatusBarController.swift   # Menu bar management
├── Models/
│   ├── Story.swift            # Core Data Story entity
│   └── Tag.swift              # Core Data Tag/Click entities
├── Core Data/
│   ├── DataController.swift   # Core Data stack
│   └── ReadGoodModel.xcdatamodeld # Data model
├── Services/
│   ├── StoryManager.swift     # Central story coordinator
│   ├── ClaudeService.swift    # AI tagging integration
│   ├── ArchiveService.swift   # Archive.ph integration
│   └── API/
│       ├── HackerNewsAPI.swift
│       ├── RedditAPI.swift
│       └── PinboardAPI.swift
└── Views/
    ├── StoryMenuView.swift    # Main popover interface
    └── SettingsView.swift     # Configuration UI
```

### Key Differences from Electron Version
- **Swift async/await** instead of JavaScript Promises
- **Core Data** instead of SQLite for object-relational mapping
- **SwiftUI** instead of HTML/CSS for native UI
- **URLSession** instead of Axios for HTTP requests
- **NSStatusItem** instead of Electron Tray for menu bar integration

## License

[Same license as original BOBrowser]

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on macOS
5. Submit a pull request

## Support

For issues or feature requests, please use the GitHub issue tracker.

## Development Notes

### Project Structure Overview
```
ReadGood/
├── ReadGoodApp.swift           # App entry point & delegate
├── StatusBarController.swift   # Menu bar management
├── Views/                     # SwiftUI interface
│   ├── StoryMenuView.swift    # Main popover
│   └── SettingsView.swift     # Configuration
├── Models/                    # Core Data entities
│   ├── Story.swift           # Story data model
│   └── Tag.swift             # Tag/Click models
├── Services/                  # Business logic
│   ├── StoryManager.swift    # Central coordinator
│   ├── ClaudeService.swift   # AI tagging
│   ├── ArchiveService.swift  # Archive.ph integration
│   └── API/                  # External APIs
└── Core Data/                 # Database
    ├── DataController.swift  # Core Data stack
    └── ReadGoodModel.xcdatamodeld
```

### Building & Testing
- **Minimum target**: macOS 13.0, Swift 5.9+
- **Dependencies**: No external Swift packages (uses system frameworks)
- **Testing**: Run in Xcode with ⌘+R, check Console.app for debug logs
- **Debugging**: All network requests and Core Data operations logged

### Code Architecture
- **@MainActor**: UI classes marked for main thread execution
- **async/await**: Modern Swift concurrency throughout
- **Core Data**: Thread-safe background operations
- **SwiftUI + AppKit**: Hybrid approach for menu bar integration

This implementation provides a solid foundation for a production macOS news aggregator with native performance and proper system integration.
