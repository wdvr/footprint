//
//  Localizable.swift
//  Footprint
//
//  Created by Claude on 2026-01-30.
//  Internationalization support for the Footprint app.
//

import Foundation

/// Provides localized strings for the Footprint app
enum L10n {
    
    // MARK: - Tab Bar
    enum Tab {
        static let map = NSLocalizedString("tab.map", comment: "Map tab title")
        static let countries = NSLocalizedString("tab.countries", comment: "Countries tab title")
        static let stats = NSLocalizedString("tab.stats", comment: "Stats tab title")
        static let settings = NSLocalizedString("tab.settings", comment: "Settings tab title")
    }
    
    // MARK: - Authentication
    enum Auth {
        static let signedIn = NSLocalizedString("auth.signed_in", comment: "Signed in status")
        static func signedInWith(_ provider: String) -> String {
            String.localizedStringWithFormat(NSLocalizedString("auth.signed_in_with", comment: "Signed in with provider"), provider)
        }
        static let offlineMode = NSLocalizedString("auth.offline_mode", comment: "Offline mode title")
        static let offlineDescription = NSLocalizedString("auth.offline_description", comment: "Offline mode description")
        static let signOut = NSLocalizedString("auth.sign_out", comment: "Sign out button")
        static let signOutConfirmation = NSLocalizedString("auth.sign_out_confirmation", comment: "Sign out confirmation message")
    }
    
    // MARK: - Sync
    enum Sync {
        static let forceFullSync = NSLocalizedString("sync.force_full_sync", comment: "Force full sync button")
        static let syncing = NSLocalizedString("sync.syncing", comment: "Syncing status")
        static let syncError = NSLocalizedString("sync.sync_error", comment: "Sync error status")
        static let synced = NSLocalizedString("sync.synced", comment: "Synced status")
        static func lastSync(_ date: String) -> String {
            String.localizedStringWithFormat(NSLocalizedString("sync.last_sync", comment: "Last sync time"), date)
        }
        static let neverSynced = NSLocalizedString("sync.never_synced", comment: "Never synced status")
        static let syncNow = NSLocalizedString("sync.sync_now", comment: "Sync now accessibility label")
    }
    
    // MARK: - Location & Permissions
    enum Location {
        static let backgroundTracking = NSLocalizedString("location.background_tracking", comment: "Background location tracking title")
        static let backgroundDescription = NSLocalizedString("location.background_description", comment: "Background location tracking description")
        static let header = NSLocalizedString("location.header", comment: "Location section header")
        static let alwaysPermission = NSLocalizedString("location.always_permission", comment: "Always permission required message")
        static let batteryEfficiency = NSLocalizedString("location.battery_efficiency", comment: "Battery efficiency note")
        static let centerCurrent = NSLocalizedString("location.center_current", comment: "Center on current location")
        static let startTracking = NSLocalizedString("location.start_tracking", comment: "Start tracking location")
    }
    
    // MARK: - Import
    enum Import {
        static let sources = NSLocalizedString("import.sources", comment: "Import sources title")
        static let sourcesDescription = NSLocalizedString("import.sources_description", comment: "Import sources description")
        static let photoLimit = NSLocalizedString("import.photo_limit", comment: "Photo limit title")
        static let photoLimitNone = NSLocalizedString("import.photo_limit_none", comment: "No photo limit")
    }
    
    // MARK: - Data Management
    enum Data {
        static let backup = NSLocalizedString("data.backup", comment: "Backup data button")
        static let restoreBackup = NSLocalizedString("data.restore_backup", comment: "Restore backup button")
        static let clearAll = NSLocalizedString("data.clear_all", comment: "Clear all data button")
        static let deleteAccount = NSLocalizedString("data.delete_account", comment: "Delete account button")
        static let deleteAccountWarning = NSLocalizedString("data.delete_account_warning", comment: "Delete account warning")
        static func clearAllConfirmation(_ count: Int) -> String {
            String.localizedStringWithFormat(NSLocalizedString("data.clear_all_confirmation", comment: "Clear all confirmation"), count)
        }
        static let backupSuccess = NSLocalizedString("data.backup_success", comment: "Backup success message")
        static let restoreConfirmation = NSLocalizedString("data.restore_confirmation", comment: "Restore confirmation message")
        static let restoreSuccess = NSLocalizedString("data.restore_success", comment: "Restore success message")
    }
    
    // MARK: - App Information
    enum App {
        static let version = NSLocalizedString("app.version", comment: "App version label")
        static let build = NSLocalizedString("app.build", comment: "App build label")
    }
    
    // MARK: - Countries & Places
    enum Places {
        static let countries = NSLocalizedString("places.countries", comment: "Countries plural")
        static let visited = NSLocalizedString("places.visited", comment: "Visited status")
        static let bucketList = NSLocalizedString("places.bucket_list", comment: "Bucket list")
        static let remove = NSLocalizedString("places.remove", comment: "Remove button")
        static let markVisited = NSLocalizedString("places.mark_visited", comment: "Mark as visited button")
        static let viewStates = NSLocalizedString("places.view_states", comment: "View states button")
        static let viewProvinces = NSLocalizedString("places.view_provinces", comment: "View provinces button")
        static func territoryOf(_ parent: String, _ code: String) -> String {
            String.localizedStringWithFormat(NSLocalizedString("places.territory_of", comment: "Territory of parent country"), parent, code)
        }
        static func code(_ code: String) -> String {
            String.localizedStringWithFormat(NSLocalizedString("places.code", comment: "Place code"), code)
        }
        static let searchCountries = NSLocalizedString("places.search_countries", comment: "Search countries placeholder")
    }
    
    // MARK: - Stats
    enum Stats {
        static let yourTravelStats = NSLocalizedString("stats.your_travel_stats", comment: "Your travel stats title")
        static let totalRegionsVisited = NSLocalizedString("stats.total_regions_visited", comment: "Total regions visited")
        static func bucketListDescription(_ count: Int) -> String {
            String.localizedStringWithFormat(NSLocalizedString("stats.bucket_list_description", comment: "Bucket list description"), count)
        }
        static let byContinent = NSLocalizedString("stats.by_continent", comment: "By continent section")
        static let timeZones = NSLocalizedString("stats.time_zones", comment: "Time zones section")
        static func timeZonesVisitedPercent(_ percent: Int) -> String {
            String.localizedStringWithFormat(NSLocalizedString("stats.time_zones_visited_percent", comment: "Time zones visited percentage"), percent)
        }
        static let farthestWest = NSLocalizedString("stats.farthest_west", comment: "Farthest west")
        static let farthestEast = NSLocalizedString("stats.farthest_east", comment: "Farthest east")
        static let achievements = NSLocalizedString("stats.achievements", comment: "Achievements section")
        static let nextAchievement = NSLocalizedString("stats.next_achievement", comment: "Next achievement")
        static let visitTypes = NSLocalizedString("stats.visit_types", comment: "Visit types section")
    }
    
    // MARK: - Onboarding
    enum Onboarding {
        static let skip = NSLocalizedString("onboarding.skip", comment: "Skip button")
        static let back = NSLocalizedString("onboarding.back", comment: "Back button")
        static let next = NSLocalizedString("onboarding.next", comment: "Next button")
        static let getStarted = NSLocalizedString("onboarding.get_started", comment: "Get started button")
        
        enum Welcome {
            static let title = NSLocalizedString("onboarding.welcome.title", comment: "Welcome title")
            static let description = NSLocalizedString("onboarding.welcome.description", comment: "Welcome description")
        }
        
        enum Photos {
            static let title = NSLocalizedString("onboarding.photos.title", comment: "Photos import title")
            static let description = NSLocalizedString("onboarding.photos.description", comment: "Photos import description")
            static let enabled = NSLocalizedString("onboarding.photos.enabled", comment: "Photo access enabled")
            static let enable = NSLocalizedString("onboarding.photos.enable", comment: "Enable photo access")
            static let optional = NSLocalizedString("onboarding.photos.optional", comment: "Photos optional note")
        }
        
        enum Location {
            static let title = NSLocalizedString("onboarding.location.title", comment: "Location tracking title")
            static let description = NSLocalizedString("onboarding.location.description", comment: "Location tracking description")
            static let enabled = NSLocalizedString("onboarding.location.enabled", comment: "Location access enabled")
            static let enable = NSLocalizedString("onboarding.location.enable", comment: "Enable location access")
            static let optional = NSLocalizedString("onboarding.location.optional", comment: "Location optional note")
        }
        
        enum Complete {
            static let title = NSLocalizedString("onboarding.complete.title", comment: "Onboarding complete title")
            static let description = NSLocalizedString("onboarding.complete.description", comment: "Onboarding complete description")
        }
    }
    
    // MARK: - Map & UI Controls
    enum Map {
        static let showPhotoPins = NSLocalizedString("map.show_photo_pins", comment: "Show photo pins")
        static let hidePhotoPins = NSLocalizedString("map.hide_photo_pins", comment: "Hide photo pins")
        static let showList = NSLocalizedString("map.show_list", comment: "Show list view")
        static let showMap = NSLocalizedString("map.show_map", comment: "Show map view")
        static let expandStates = NSLocalizedString("map.expand_states", comment: "Expand states")
        static let collapseStates = NSLocalizedString("map.collapse_states", comment: "Collapse states")
    }
    
    // MARK: - Common Actions
    enum Action {
        static let cancel = NSLocalizedString("action.cancel", comment: "Cancel action")
        static let delete = NSLocalizedString("action.delete", comment: "Delete action")
        static let ok = NSLocalizedString("action.ok", comment: "OK action")
        static let done = NSLocalizedString("action.done", comment: "Done action")
        static let restore = NSLocalizedString("action.restore", comment: "Restore action")
    }
    
    // MARK: - Accessibility
    enum Accessibility {
        static func visitedStatus(_ place: String, _ status: String) -> String {
            String.localizedStringWithFormat(NSLocalizedString("accessibility.visited_status", comment: "Visited status accessibility"), place, status)
        }
        static let visited = NSLocalizedString("accessibility.visited", comment: "Visited accessibility")
        static let notVisited = NSLocalizedString("accessibility.not_visited", comment: "Not visited accessibility")
        static func continentStats(_ continent: String, _ visited: Int, _ total: Int) -> String {
            String.localizedStringWithFormat(NSLocalizedString("accessibility.continent_stats", comment: "Continent stats accessibility"), continent, visited, total)
        }
        static func bucketListCount(_ count: Int, _ places: String) -> String {
            String.localizedStringWithFormat(NSLocalizedString("accessibility.bucket_list_count", comment: "Bucket list count accessibility"), count, places)
        }
        static func statsPercentage(_ title: String, _ count: Int, _ total: Int, _ percent: Int) -> String {
            String.localizedStringWithFormat(NSLocalizedString("accessibility.stats_percentage", comment: "Stats percentage accessibility"), title, count, total, percent)
        }
        static func totalRegions(_ count: Int) -> String {
            String.localizedStringWithFormat(NSLocalizedString("accessibility.total_regions", comment: "Total regions accessibility"), count)
        }
    }
    
    // MARK: - Error Messages
    enum Error {
        static let unknown = NSLocalizedString("error.unknown", comment: "Unknown error")
        static let backupFailed = NSLocalizedString("error.backup_failed", comment: "Backup failed error")
        static let restoreFailed = NSLocalizedString("error.restore_failed", comment: "Restore failed error")
    }
    
    // MARK: - Geographic Terms
    enum Geographic {
        static let continent = NSLocalizedString("geographic.continent", comment: "Continent")
        static let country = NSLocalizedString("geographic.country", comment: "Country")
        static let state = NSLocalizedString("geographic.state", comment: "State")
        static let province = NSLocalizedString("geographic.province", comment: "Province")
        static let territory = NSLocalizedString("geographic.territory", comment: "Territory")
    }
    
    // MARK: - Continents
    enum Continent {
        static let africa = NSLocalizedString("continent.africa", comment: "Africa continent")
        static let antarctica = NSLocalizedString("continent.antarctica", comment: "Antarctica continent")
        static let asia = NSLocalizedString("continent.asia", comment: "Asia continent")
        static let europe = NSLocalizedString("continent.europe", comment: "Europe continent")
        static let northAmerica = NSLocalizedString("continent.north_america", comment: "North America continent")
        static let oceania = NSLocalizedString("continent.oceania", comment: "Oceania continent")
        static let southAmerica = NSLocalizedString("continent.south_america", comment: "South America continent")
    }
}

// MARK: - String Extension for Localization
extension String {
    /// Returns a localized version of the string
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Returns a localized string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        return String.localizedStringWithFormat(NSLocalizedString(self, comment: ""), arguments)
    }
}
