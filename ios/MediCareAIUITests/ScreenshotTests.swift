import XCTest

/// Saves a screenshot of every main screen, light and dark, with sample data. CI exports
/// them as the "screenshots" artifact. The device region is Denmark (112, "Monday 23 November").
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testLightScreens() throws {
        captureAll(colorScheme: "light")
    }

    func testDarkScreens() throws {
        captureAll(colorScheme: "dark")
    }

    private func captureAll(colorScheme: String) {
        captureWelcome(colorScheme)
        captureSignIn(colorScheme)
        captureSignedIn(colorScheme)
    }

    private func captureWelcome(_ scheme: String) {
        let app = XCUIApplication.mock(signedIn: false, locale: "en_DK", colorScheme: scheme, onboardingDone: false)
        app.launch()
        let next = app.buttons["onboarding.next"]
        guard next.waitForExistence(timeout: 12) else {
            XCTFail("Welcome pages did not open")
            return
        }
        pause(1.8)
        snap(app, scheme, "01-welcome")
        next.tap()
        pause(0.8)
        snap(app, scheme, "02-fits-you")
        next.tap()
        pause(0.8)
        snap(app, scheme, "03-what-is-shared")
        app.terminate()
    }

    private func captureSignIn(_ scheme: String) {
        let app = XCUIApplication.mock(signedIn: false, locale: "en_DK", colorScheme: scheme)
        app.launch()
        XCTAssertTrue(app.buttons["login.submit"].waitForExistence(timeout: 12))
        pause(1.5)
        snap(app, scheme, "04-sign-in")
        app.terminate()
    }

    private func captureSignedIn(_ scheme: String) {
        let app = XCUIApplication.mock(signedIn: true, seeded: true, locale: "en_DK", colorScheme: scheme)
        app.launch()

        XCTAssertTrue(app.element("home.greeting").waitForExistence(timeout: 15))
        XCTAssertTrue(app.element("home.recent.0").waitForExistence(timeout: 8))
        pause(1.8)
        snap(app, scheme, "05-home")

        // A finished answer from the sample chats.
        app.element("home.recent.0").tap()
        if app.buttons["citation.1"].waitForExistence(timeout: 10) {
            pause(0.8)
            snap(app, scheme, "06-answer")
            app.buttons["citation.1"].tap()
            if app.buttons["citation.done"].waitForExistence(timeout: 5) {
                pause(0.8)
                snap(app, scheme, "07-source")
                app.buttons["citation.done"].tap()
            }
        } else {
            XCTFail("The sample answer did not open")
        }
        app.goBack()

        // A topic with its example questions.
        let topic = app.element("home.topic.medicines")
        if topic.waitForExistence(timeout: 8) {
            topic.tap()
            if app.element("chat.welcome").waitForExistence(timeout: 5) {
                pause(0.6)
                snap(app, scheme, "08-topic")
            }
            app.goBack()
        }

        // An emergency answer.
        app.type("I have a tight pain in my chest and it's spreading to my left arm", into: "home.input")
        app.element("home.send").tap()
        if app.buttons["chat.callEmergency"].waitForExistence(timeout: 15) {
            _ = app.element("chat.listen").waitForExistence(timeout: 10)
            pause(0.8)
            snap(app, scheme, "09-emergency")
        } else {
            XCTFail("The emergency card did not show")
        }
        app.goBack()

        // Past chats.
        let seeAll = app.element("home.seeAll")
        if seeAll.waitForExistence(timeout: 8) {
            seeAll.tap()
            pause(1)
            snap(app, scheme, "10-past-chats")
            app.goBack()
        }

        // My health, updated from a chat.
        app.tabBars.buttons["My health"].tap()
        XCTAssertTrue(app.buttons["v10.undo"].waitForExistence(timeout: 8))
        pause(0.8)
        snap(app, scheme, "11-my-health")

        // Settings.
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["settings.highContrast"].waitForExistence(timeout: 8))
        pause(0.8)
        snap(app, scheme, "12-settings")
        app.terminate()
    }

    private func snap(_ app: XCUIApplication, _ scheme: String, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(scheme)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }
}
