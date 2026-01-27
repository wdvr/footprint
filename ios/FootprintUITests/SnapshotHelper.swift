//
//  SnapshotHelper.swift
//  Example
//
//  Created by Felix Krause on 10/8/15.
//

// -----------------------------------------------------
// IMPORTANT: When modifying this file, make sure to
//            increment the version number at the bottom
//            of this file to notify users about
//            an update.
// -----------------------------------------------------

import Foundation
import XCTest

var deviceLanguage = ""
var locale = ""

func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
    Snapshot.setupSnapshot(app, waitForAnimations: waitForAnimations)
}

func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) {
    Snapshot.snapshot(name, timeWaitingForIdle: timeout)
}

enum SnapshotError: Error, CustomDebugStringConvertible {
    case cannotDetectUser
    case cannotFindSimulatorHomeDirectory
    case cannotFindSnapshotDirectory
    case cannotRunOnPhysicalDevice

    var debugDescription: String {
        switch self {
        case .cannotDetectUser:
            return "Couldn't find Snapshot configuration files - can't detect current user "
        case .cannotFindSimulatorHomeDirectory:
            return "Couldn't find simulator home location. Please, check SIMULATOR_HOST_HOME env variable."
        case .cannotFindSnapshotDirectory:
            return "Couldn't find snapshot directory"
        case .cannotRunOnPhysicalDevice:
            return "Can't use Snapshot on a physical device."
        }
    }
}

@objc(Snapshot)
open class Snapshot: NSObject {
    static var app: XCUIApplication?
    static var waitForAnimations = true

    open class func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
        Snapshot.app = app
        Snapshot.waitForAnimations = waitForAnimations

        #if arch(i386) || arch(x86_64)
            // We're on a simulator
            if Snapshot.waitForAnimations {
                disableAnimations()
            }
        #endif
    }

    class func disableAnimations() {
        #if arch(i386) || arch(x86_64)
            app?.launchArguments += ["-UIApplication.disableCoreAnimations", "true"]
        #endif
    }

    open class func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) {
        if timeout > 0 {
            waitForLoadingIndicatorToDisappear(within: timeout)
        }

        #if arch(i386) || arch(x86_64)
            print("📷  Snapshot: \(name)")

            sleep(1) // Executed on main thread with a 1 second delay.
            // The delayed execution is intentional to allow time for the animations to finish
            let screenshot = XCUIScreen.main.screenshot()

            guard var simulator = ProcessInfo().environment["SIMULATOR_DEVICE_NAME"] else {
                print("⚠️  Couldn't detect simulator")
                return
            }

            // Trim whitespace and unwanted characters
            simulator = simulator.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            simulator = simulator.replacingOccurrences(of: " ", with: "-")
            simulator = simulator.replacingOccurrences(of: "(", with: "")
            simulator = simulator.replacingOccurrences(of: ")", with: "")

            let path = screenshotPath()
            let screenshotDir = "\(path)/\(simulator)"

            do {
                try FileManager.default.createDirectory(atPath: screenshotDir, withIntermediateDirectories: true, attributes: nil)
                let screenshotPath = "\(screenshotDir)/\(name).png"
                try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: screenshotPath))
                print("📱  Saved screenshot at \(screenshotPath)")
            } catch {
                print("❌  Problem saving screenshot: \(error)")
            }
        #endif
    }

    class func waitForLoadingIndicatorToDisappear(within timeout: TimeInterval) {
        #if arch(i386) || arch(x86_64)
            guard let app = self.app else {
                print("⚠️  No app reference available")
                return
            }

            let networkLoadingIndicator = app.statusBars.networkLoadingIndicators.element
            let loadingIndicator = app.activityIndicators.element

            let disappearanceExpectation = XCTestExpectation(description: "Loading indicator disappeared")

            let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                if !networkLoadingIndicator.exists && !loadingIndicator.exists {
                    disappearanceExpectation.fulfill()
                }
            }

            _ = XCTWaiter.wait(for: [disappearanceExpectation], timeout: timeout)
            timer.invalidate()
        #endif
    }

    class func screenshotPath() -> String {
        if let screenshotDir = ProcessInfo.processInfo.environment["FASTLANE_SNAPSHOT_OUTPUT_DIRECTORY"] {
            return screenshotDir
        }

        // Default to fastlane screenshots directory
        return "fastlane/screenshots"
    }
}

extension XCUIElementQuery {
    var networkLoadingIndicators: XCUIElementQuery {
        return self.descendants(matching: .other).matching(identifier: "In Call")
    }
}