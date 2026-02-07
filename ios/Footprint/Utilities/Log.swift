import Foundation
import os

/// Centralized logging using os.Logger framework.
///
/// Usage: `Log.auth.debug("Token refreshed")` or `Log.api.error("Request failed: \(error)")`
///
/// Log levels:
/// - `.debug`   - Verbose debugging info, stripped from release builds
/// - `.info`    - Informational, not persisted by default
/// - `.notice`  - Important state changes, persisted (default level)
/// - `.warning` - Potential issues that don't prevent operation (via `.error` with warning prefix)
/// - `.error`   - Errors that affect functionality
/// - `.fault`   - Critical failures that may crash the app
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.wd.footprint.app"

    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let api = Logger(subsystem: subsystem, category: "API")
    static let keychain = Logger(subsystem: subsystem, category: "Keychain")
    static let photoImport = Logger(subsystem: subsystem, category: "PhotoImport")
    static let photoStore = Logger(subsystem: subsystem, category: "PhotoStore")
    static let geo = Logger(subsystem: subsystem, category: "GeoJSON")
    static let geoMatcher = Logger(subsystem: subsystem, category: "GeoMatcher")
    static let map = Logger(subsystem: subsystem, category: "Map")
    static let location = Logger(subsystem: subsystem, category: "Location")
    static let push = Logger(subsystem: subsystem, category: "Push")
    static let googleAuth = Logger(subsystem: subsystem, category: "GoogleAuth")
    static let googleImport = Logger(subsystem: subsystem, category: "GoogleImport")
    static let app = Logger(subsystem: subsystem, category: "App")
    static let friends = Logger(subsystem: subsystem, category: "Friends")
    static let photoGallery = Logger(subsystem: subsystem, category: "PhotoGallery")
    static let analytics = Logger(subsystem: subsystem, category: "Analytics")
    static let data = Logger(subsystem: subsystem, category: "Data")
    static let importFlow = Logger(subsystem: subsystem, category: "Import")
}
