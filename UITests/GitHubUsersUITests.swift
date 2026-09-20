import XCTest

final class GitHubUsersUITests: XCTestCase {
    @MainActor private func launch(state: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_MOCK", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        if let state {
            app.launchArguments += ["-UITEST_STATE", state]
        }
        app.launch()
        return app
    }

    @MainActor func testGridDetailBackAndAvatar() {
        let app = launch()
        let first = app.buttons["user-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let origin = first.frame.minY
        capture(app, name: "01-grid")
        first.tap()
        XCTAssertTrue(app.staticTexts["detailLogin"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["detailLogin"].label, "mojombo")
        capture(app, name: "02-detail")
        app.buttons["openAvatar"].tap()
        XCTAssertTrue(app.buttons["closeAvatar"].waitForExistence(timeout: 5))
        capture(app, name: "03-avatar")
        app.buttons["closeAvatar"].tap()
        app.buttons["openAvatar"].tap()
        app.descendants(matching: .any)["fullScreenAvatar"].firstMatch.tap()
        XCTAssertTrue(app.buttons["openAvatar"].waitForExistence(timeout: 5))
        app.buttons["BackButton"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.frame.minY, origin, accuracy: 4)
    }

    @MainActor func testToggleSearchAndClear() {
        let app = launch()
        XCTAssertTrue(app.buttons["user-1"].waitForExistence(timeout: 10))
        app.buttons["layoutToggle"].tap()
        XCTAssertTrue(app.scrollViews["usersList"].exists)
        app.buttons["layoutToggle"].tap()
        XCTAssertTrue(app.scrollViews["usersGrid"].exists)
        let search = app.searchFields.firstMatch
        if !search.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("mojo")
        XCTAssertTrue(app.buttons["user-1"].exists)
        XCTAssertFalse(app.buttons["user-2"].exists)
        search.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["user-2"].waitForExistence(timeout: 5))
    }

    @MainActor func testPaginationAndRotation() {
        let app = launch()
        XCTAssertTrue(app.buttons["user-1"].waitForExistence(timeout: 10))
        for _ in 0 ..< 20 where !app.buttons["user-31"].exists {
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["user-31"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let grid = app.scrollViews["usersGrid"]
        let predicate = NSPredicate(format: "value IN %@", ["2", "3", "4"])
        expectation(for: predicate, evaluatedWith: grid)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["layoutToggle"].isHittable)
    }

    @MainActor func testOfflineErrorRetry() {
        let app = launch(state: "error")
        let retry = app.buttons["retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertTrue(retry.isEnabled)
        retry.tap()
        XCTAssertTrue(app.buttons["user-1"].waitForExistence(timeout: 5))
    }

    @MainActor func testBackgroundPreservesDetailAndNavigation() {
        let app = launch()
        XCTAssertTrue(app.buttons["user-1"].waitForExistence(timeout: 10))
        let first = app.buttons["user-1"]
        XCTAssertTrue(first.isHittable)
        capture(app, name: "background-before-open")
        first.tap()
        capture(app, name: "background-after-open")
        XCTAssertTrue(app.staticTexts["detailLogin"].waitForExistence(timeout: 5))
        app.buttons["simulateBackgroundReturn"].tap()
        XCTAssertTrue(app.staticTexts["detailLogin"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["detailLogin"].label, "mojombo")
        app.buttons["BackButton"].tap()
        XCTAssertTrue(app.buttons["user-1"].waitForExistence(timeout: 5))
    }

    @MainActor private func capture(_: XCUIApplication, name: String) {
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = "\(name)-screen-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor func testDetailRefreshFailureKeepsProfileAndRetryRecovers() {
        let app = launch(state: "detail-refresh-error")
        let first = app.buttons["user-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
        let originalBio = app.staticTexts["Building tools for people who build things."]
        XCTAssertTrue(originalBio.waitForExistence(timeout: 5))
        app.buttons["simulateBackgroundReturn"].tap()
        let warning = app.descendants(matching: .any)["detailRefreshError"].firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 10))
        XCTAssertTrue(originalBio.exists)
        XCTAssertEqual(app.staticTexts["detailLogin"].label, "mojombo")
        let retry = app.buttons["retry"]
        for _ in 0 ..< 4 where !retry.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(retry.isHittable)
        capture(app, name: "detail-refresh-warning")
        retry.tap()
        XCTAssertTrue(app.staticTexts["Updated profile after retry."].waitForExistence(timeout: 5))
        let disappeared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: warning)
        XCTAssertEqual(XCTWaiter.wait(for: [disappeared], timeout: 5), .completed)
    }

    @MainActor func testLaunchPerformance() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_MOCK"]
        measure(metrics: [XCTApplicationLaunchMetric()]) { app.launch() }
    }

    @MainActor func testProfileLayoutAfterScrollingAndRotation() {
        XCUIDevice.shared.orientation = .portrait
        let app = launch()
        let first = app.buttons["user-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
        XCTAssertTrue(app.staticTexts["detailLogin"].waitForExistence(timeout: 5))
        let avatar = app.buttons["openAvatar"]
        XCTAssertTrue(avatar.isHittable)
        capture(app, name: "profile-cover-portrait")

        app.swipeUp()
        app.swipeDown()
        XCTAssertTrue(avatar.isHittable)
        capture(app, name: "profile-cover-after-scroll")

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(avatar.waitForExistence(timeout: 5))
        XCTAssertTrue(avatar.isHittable)
        capture(app, name: "profile-cover-landscape")
        avatar.tap()
        XCTAssertTrue(app.buttons["closeAvatar"].waitForExistence(timeout: 5))
        app.buttons["closeAvatar"].tap()
        XCTAssertTrue(avatar.isHittable)
    }

    @MainActor func testProfileScrollPerformance() {
        let app = launch()
        let first = app.buttons["user-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
        XCTAssertTrue(app.staticTexts["detailLogin"].waitForExistence(timeout: 5))

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        // Offline data isolates layout and scrolling; image/network costs are not measured here.
        measure(
            metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
            options: options
        ) {
            app.swipeUp()
            app.swipeDown()
        }
    }
}
