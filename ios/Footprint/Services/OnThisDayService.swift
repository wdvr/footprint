//
//  OnThisDayService.swift
//  Footprint
//
//  Surfaces travel memories from past years: "3 years ago today, you were in Tokyo."
//

import Foundation
import SwiftData
@preconcurrency import UserNotifications

/// A memory match for "On This Day"
struct OnThisDayMemory: Identifiable, Equatable {
    let id: UUID
    let place: VisitedPlace
    let yearsAgo: Int

    /// Flag emoji for country-type places
    var flagEmoji: String {
        guard place.regionTypeEnum == .country else { return "" }
        let base: UInt32 = 127397
        var flag = ""
        for scalar in place.regionCode.uppercased().unicodeScalars {
            if let unicode = UnicodeScalar(base + scalar.value) {
                flag.append(String(unicode))
            }
        }
        return flag
    }

    /// Human-readable description
    var description: String {
        let yearText = yearsAgo == 1 ? "1 year ago today" : "\(yearsAgo) years ago today"
        return "\(yearText), you visited \(place.regionName)"
    }

    static func == (lhs: OnThisDayMemory, rhs: OnThisDayMemory) -> Bool {
        lhs.id == rhs.id
    }
}

/// Service that checks for travel memories matching today's date from previous years
@MainActor
@Observable
final class OnThisDayService {
    static let shared = OnThisDayService()

    /// Current memories for today
    var todayMemories: [OnThisDayMemory] = []

    /// Whether the user has dismissed the card for today
    var isDismissedForToday: Bool {
        get {
            guard let dismissedDate = UserDefaults.standard.object(forKey: Keys.lastDismissedDate) as? Date else {
                return false
            }
            return Calendar.current.isDateInToday(dismissedDate)
        }
        set {
            if newValue {
                UserDefaults.standard.set(Date(), forKey: Keys.lastDismissedDate)
            }
        }
    }

    /// Whether On This Day notifications are enabled
    var notificationsEnabled: Bool {
        get {
            // Default to true
            if UserDefaults.standard.object(forKey: Keys.notificationsEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.notificationsEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.notificationsEnabled)
            if newValue {
                // Re-check and schedule if enabled
                Task {
                    scheduleNotificationIfNeeded()
                }
            } else {
                // Remove any pending On This Day notifications
                UNUserNotificationCenter.current().removePendingNotificationRequests(
                    withIdentifiers: ["on-this-day"]
                )
            }
        }
    }

    private enum Keys {
        static let lastDismissedDate = "onThisDay_lastDismissedDate"
        static let notificationsEnabled = "onThisDay_notificationsEnabled"
        static let lastNotificationDate = "onThisDay_lastNotificationDate"
    }

    private init() {}

    // MARK: - Public API

    /// Check visited places for "on this day" matches. Call on app launch.
    func checkForMemories(visitedPlaces: [VisitedPlace]) {
        let calendar = Calendar.current
        let today = Date()
        let todayMonth = calendar.component(.month, from: today)
        let todayDay = calendar.component(.day, from: today)
        let todayYear = calendar.component(.year, from: today)

        var memories: [OnThisDayMemory] = []

        for place in visitedPlaces {
            guard !place.isDeleted,
                  place.isVisited,
                  let visitedDate = place.visitedDate else { continue }

            let visitMonth = calendar.component(.month, from: visitedDate)
            let visitDay = calendar.component(.day, from: visitedDate)
            let visitYear = calendar.component(.year, from: visitedDate)

            // Match month+day, but must be a previous year
            if visitMonth == todayMonth && visitDay == todayDay && visitYear < todayYear {
                let yearsAgo = todayYear - visitYear
                memories.append(OnThisDayMemory(
                    id: place.id,
                    place: place,
                    yearsAgo: yearsAgo
                ))
            }

            // Also check if today falls within a visit range (visitedDate...departureDate)
            if let departureDate = place.departureDate, visitYear < todayYear {
                // Check if today's month+day falls within the range in the visit year
                let visitDayOfYear = calendar.ordinality(of: .day, in: .year, for: visitedDate) ?? 0
                let departureDayOfYear = calendar.ordinality(of: .day, in: .year, for: departureDate) ?? 0
                let todayDayOfYear = calendar.ordinality(of: .day, in: .year, for: today) ?? 0

                // Only check range if we haven't already matched the exact start date
                if visitMonth != todayMonth || visitDay != todayDay {
                    if todayDayOfYear >= visitDayOfYear && todayDayOfYear <= departureDayOfYear {
                        let yearsAgo = todayYear - visitYear
                        // Avoid duplicates
                        if !memories.contains(where: { $0.id == place.id }) {
                            memories.append(OnThisDayMemory(
                                id: place.id,
                                place: place,
                                yearsAgo: yearsAgo
                            ))
                        }
                    }
                }
            }
        }

        // Sort by most recent first
        memories.sort { $0.yearsAgo < $1.yearsAgo }
        todayMemories = memories

        // Schedule notification if we have memories
        if !memories.isEmpty {
            scheduleNotificationIfNeeded()
        }
    }

    /// Dismiss the card for today
    func dismissForToday() {
        isDismissedForToday = true
    }

    // MARK: - Notifications

    /// Schedule a local notification for today's memory (if not already sent today)
    private func scheduleNotificationIfNeeded() {
        guard notificationsEnabled else { return }
        guard !todayMemories.isEmpty else { return }

        // Check if we already sent a notification today
        if let lastDate = UserDefaults.standard.object(forKey: Keys.lastNotificationDate) as? Date,
           Calendar.current.isDateInToday(lastDate) {
            return
        }

        let memory = todayMemories[0] // Use the most recent memory

        let content = UNMutableNotificationContent()
        content.title = "Travel Memory"
        content.body = "\(memory.yearsAgo) \(memory.yearsAgo == 1 ? "year" : "years") ago today, you were in \(memory.place.regionName)!"
        if !memory.flagEmoji.isEmpty {
            content.body = "\(memory.flagEmoji) " + content.body
        }
        content.sound = .default
        content.userInfo = [
            "action": "on_this_day",
            "place_id": memory.place.id.uuidString,
            "region_name": memory.place.regionName
        ]

        let request = UNNotificationRequest(
            identifier: "on-this-day",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
        UserDefaults.standard.set(Date(), forKey: Keys.lastNotificationDate)

        Log.push.info("Scheduled On This Day notification for \(memory.place.regionName)")
    }
}
