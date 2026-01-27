import Foundation
import SwiftData

/// Helper class for creating sample data for UI testing and screenshots
@MainActor
struct SampleDataHelper {

    /// Adds sample visited places to the container for attractive screenshots
    static func addSampleData(to container: ModelContainer) {
        let context = container.mainContext

        // Check if sample data already exists
        do {
            let descriptor = FetchDescriptor<VisitedPlace>()
            let existingPlaces = try context.fetch(descriptor)
            if !existingPlaces.isEmpty {
                return // Sample data already exists
            }
        } catch {
            print("Error checking for existing data: \(error)")
            return
        }

        // Sample visited places for attractive screenshots
        let samplePlaces = [
            // North America - Countries
            VisitedPlace(
                regionType: .country,
                regionCode: "US",
                regionName: "United States",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "CA",
                regionName: "Canada",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "MX",
                regionName: "Mexico",
                visitedDate: randomDateWithinLastYear()
            ),

            // US States for state view screenshots
            VisitedPlace(
                regionType: .usState,
                regionCode: "US-CA",
                regionName: "California",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .usState,
                regionCode: "US-NY",
                regionName: "New York",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .usState,
                regionCode: "US-FL",
                regionName: "Florida",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .usState,
                regionCode: "US-TX",
                regionName: "Texas",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .usState,
                regionCode: "US-WA",
                regionName: "Washington",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .usState,
                regionCode: "US-IL",
                regionName: "Illinois",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .usState,
                regionCode: "US-NV",
                regionName: "Nevada",
                visitedDate: randomDateWithinLastYear()
            ),

            // Canadian provinces
            VisitedPlace(
                regionType: .canadianProvince,
                regionCode: "CA-ON",
                regionName: "Ontario",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .canadianProvince,
                regionCode: "CA-BC",
                regionName: "British Columbia",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .canadianProvince,
                regionCode: "CA-QC",
                regionName: "Quebec",
                visitedDate: randomDateWithinLastYear()
            ),

            // Europe - Great coverage for map visualization
            VisitedPlace(
                regionType: .country,
                regionCode: "FR",
                regionName: "France",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "IT",
                regionName: "Italy",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "ES",
                regionName: "Spain",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "DE",
                regionName: "Germany",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "GB",
                regionName: "United Kingdom",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "NL",
                regionName: "Netherlands",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "CH",
                regionName: "Switzerland",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "AT",
                regionName: "Austria",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "SE",
                regionName: "Sweden",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "NO",
                regionName: "Norway",
                visitedDate: randomDateWithinLastYear()
            ),

            // Asia
            VisitedPlace(
                regionType: .country,
                regionCode: "JP",
                regionName: "Japan",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "TH",
                regionName: "Thailand",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "SG",
                regionName: "Singapore",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "KR",
                regionName: "South Korea",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "VN",
                regionName: "Vietnam",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "MY",
                regionName: "Malaysia",
                visitedDate: randomDateWithinLastYear()
            ),

            // Oceania
            VisitedPlace(
                regionType: .country,
                regionCode: "AU",
                regionName: "Australia",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "NZ",
                regionName: "New Zealand",
                visitedDate: randomDateWithinLastYear()
            ),

            // South America
            VisitedPlace(
                regionType: .country,
                regionCode: "BR",
                regionName: "Brazil",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "AR",
                regionName: "Argentina",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "PE",
                regionName: "Peru",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "CL",
                regionName: "Chile",
                visitedDate: randomDateWithinLastYear()
            ),

            // Africa
            VisitedPlace(
                regionType: .country,
                regionCode: "ZA",
                regionName: "South Africa",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "EG",
                regionName: "Egypt",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "MA",
                regionName: "Morocco",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "KE",
                regionName: "Kenya",
                visitedDate: randomDateWithinLastYear()
            ),
            VisitedPlace(
                regionType: .country,
                regionCode: "TZ",
                regionName: "Tanzania",
                visitedDate: randomDateWithinLastYear()
            ),
        ]

        // Add all sample places to the context
        for place in samplePlaces {
            context.insert(place)
        }

        // Save the sample data
        do {
            try context.save()
            print("✅ Sample data added successfully for screenshots")
        } catch {
            print("❌ Error saving sample data: \(error)")
        }
    }

    /// Generates a random date within the last year for varied visit dates
    private static func randomDateWithinLastYear() -> Date {
        let now = Date()
        let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        let randomTimeInterval = Double.random(in: 0...now.timeIntervalSince(yearAgo))
        return yearAgo.addingTimeInterval(randomTimeInterval)
    }
}