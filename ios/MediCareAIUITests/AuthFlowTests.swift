import XCTest

/// The main journeys against the mock sign-in and mock API.
final class AuthFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Sign in and sign up

    func testLoginScreenAppears() throws {
        let app = XCUIApplication.mock(signedIn: false)
        app.launch()

        XCTAssertTrue(app.buttons["login.submit"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["login.createAccount"].exists)
    }

    func testSignUpGreetsByFirstName() throws {
        let app = XCUIApplication.mock(signedIn: false)
        app.launch()

        XCTAssertTrue(app.buttons["login.createAccount"].waitForExistence(timeout: 10))
        app.buttons["login.createAccount"].tap()
        app.type("inge", into: "signup.firstName")
        app.type("inge@example.com", into: "signup.email")
        app.type("TestPass1234", into: "signup.password")
        app.type("TestPass1234", into: "signup.confirmPassword")

        let submit = app.buttons["signup.submit"]
        XCTAssertTrue(submit.waitUntilEnabled(timeout: 6), "Create account should be enabled")
        submit.tap()

        let greeting = app.element("home.greeting")
        XCTAssertTrue(greeting.waitForExistence(timeout: 15), "Home should open after sign-up")
        XCTAssertTrue(greeting.label.hasSuffix(", Inge"), "Greeting was: \(greeting.label)")
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
        XCTAssertTrue(app.tabBars.buttons["My health"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }

    func testSignUpButtonDisabledWhenPasswordsMismatch() throws {
        let app = XCUIApplication.mock(signedIn: false)
        app.launch()

        XCTAssertTrue(app.buttons["login.createAccount"].waitForExistence(timeout: 10))
        app.buttons["login.createAccount"].tap()
        app.type("inge@example.com", into: "signup.email")
        app.type("TestPass1234", into: "signup.password")
        app.type("Mismatch1234", into: "signup.confirmPassword")

        XCTAssertFalse(app.buttons["signup.submit"].isEnabled)
    }

    func testWhatGetsSharedMentionsVoiceInput() throws {
        let app = XCUIApplication.mock(signedIn: false, onboardingDone: false)
        app.launch()

        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 12))
        next.tap()
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "page")], timeout: 0.8)
        next.tap()

        let voice = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "speech recognition"))
            .firstMatch
        XCTAssertTrue(voice.waitForExistence(timeout: 5), "The privacy page should say where spoken questions go")
    }

    // MARK: - Asking

    func testAskFromHomeShowsASectionedAnswerWithSources() throws {
        let app = XCUIApplication.mock(signedIn: true)
        app.launch()

        app.type("Is coffee okay with metformin?", into: "home.input", timeout: 15)
        app.element("home.send").tap()

        XCTAssertTrue(app.buttons["citation.1"].waitForExistence(timeout: 15), "Sources should show")
        XCTAssertTrue(app.buttons["citation.3"].exists)
        XCTAssertGreaterThanOrEqual(app.buttons["citation.1"].frame.height.rounded(), 44, "Source chips need a 44 pt touch target")
        XCTAssertTrue(app.element("answer.lead").exists, "The short answer should show")
        XCTAssertTrue(app.element("answer.doThis").exists)
        XCTAssertTrue(app.element("answer.watchFor").exists)
        XCTAssertTrue(app.element("chat.listen").waitForExistence(timeout: 5))

        app.buttons["citation.2"].tap()
        XCTAssertTrue(app.buttons["citation.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Caffeine and diabetes"].exists)
        app.buttons["citation.done"].tap()
    }

    func testTopicFillsTheQuestionWithoutSending() throws {
        let app = XCUIApplication.mock(signedIn: true)
        app.launch()

        let topic = app.element("home.topic.medicines")
        XCTAssertTrue(topic.waitForExistence(timeout: 15))
        topic.tap()
        XCTAssertTrue(app.element("chat.welcome").waitForExistence(timeout: 5))

        let example = "Can I take ibuprofen with my blood pressure tablets?"
        app.buttons[example].tap()

        let input = app.element("chat.input")
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, example)
        XCTAssertFalse(app.element("chat.status").waitForExistence(timeout: 2), "Nothing should be sent")
        XCTAssertFalse(app.buttons["citation.1"].exists)
    }

    func testEmergencyAnswerCallsTheLocalNumber() throws {
        let app = XCUIApplication.mock(signedIn: true, locale: "en_US")
        app.launch()

        app.type("I have chest pain going down my left arm", into: "home.input", timeout: 15)
        app.element("home.send").tap()

        let call = app.buttons["chat.callEmergency"]
        XCTAssertTrue(call.waitForExistence(timeout: 15))
        XCTAssertEqual(call.label, "Call 911")
    }

    // MARK: - My health

    func testHealthProfileSaves() throws {
        let app = XCUIApplication.mock(signedIn: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["My health"].waitForExistence(timeout: 15))
        app.tabBars.buttons["My health"].tap()
        let setup = app.buttons["v10.setup"]
        XCTAssertTrue(setup.waitForExistence(timeout: 8))
        setup.tap()

        let heading = app.buttons["v10.heading.Conditions"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(heading.frame.height.rounded(), 44, "Heading chips need a 44 pt touch target")

        app.type("Conditions: Hypertension", into: "v10.editor")
        app.buttons["v10.save"].tap()

        XCTAssertTrue(app.staticTexts["Hypertension"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Conditions"].exists)
        XCTAssertTrue(app.buttons["v10.edit"].exists)
    }

    func testUndoRemovesWhatAChatAdded() throws {
        let app = XCUIApplication.mock(signedIn: true, seeded: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["My health"].waitForExistence(timeout: 15))
        app.tabBars.buttons["My health"].tap()
        XCTAssertTrue(app.staticTexts["Dizzy spells in the morning"].waitForExistence(timeout: 8))

        app.buttons["v10.undo"].tap()

        XCTAssertTrue(app.staticTexts["Dizzy spells in the morning"].waitUntilGone(timeout: 8))
        XCTAssertTrue(app.staticTexts["Metformin 500 mg with breakfast"].exists)
    }

    // MARK: - Settings

    func testHighContrastToggles() throws {
        let app = XCUIApplication.mock(signedIn: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        let toggle = app.switches["settings.highContrast"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        let before = toggle.value as? String

        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()

        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate { element, _ in ((element as? XCUIElement)?.value as? String) != before },
            object: toggle
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 8), .completed)
    }

    func testExtraLargeTextKeepsSettingsOpen() throws {
        let app = XCUIApplication.mock(signedIn: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        let toggle = app.switches["settings.fontSize"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        let before = toggle.value as? String

        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "save")], timeout: 2)

        XCTAssertTrue(app.element("screen.settings").exists, "Settings should stay open")
        XCTAssertNotEqual(app.switches["settings.fontSize"].value as? String, before)
    }

    func testLogOutReturnsToSignIn() throws {
        let app = XCUIApplication.mock(signedIn: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["settings.highContrast"].waitForExistence(timeout: 8))
        let logout = app.buttons["settings.logout"]
        XCTAssertTrue(app.scrollUntilExists(logout), "Log out should be at the bottom of Settings")
        logout.tap()
        let confirm = app.alerts.buttons["Log out"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.buttons["login.submit"].waitForExistence(timeout: 10))
    }
}
