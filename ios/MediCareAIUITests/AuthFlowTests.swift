import XCTest

final class AuthFlowTests: XCTestCase {
    let app = XCUIApplication()
    private var authMode: String = "mock"
    private var apiMode: String = "mock"
    private var apiBaseURL: String?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"]
        authMode = ProcessInfo.processInfo.environment["UITEST_AUTH_MODE"]
            ?? ProcessInfo.processInfo.environment["AUTH_MODE"]
            ?? "mock"
        apiMode = ProcessInfo.processInfo.environment["UITEST_API_MODE"]
            ?? ProcessInfo.processInfo.environment["API_MODE"]
            ?? "mock"
        apiBaseURL = ProcessInfo.processInfo.environment["UITEST_API_BASE_URL"]
            ?? ProcessInfo.processInfo.environment["API_BASE_URL"]
        app.launchEnvironment["AUTH_MODE"] = authMode
        app.launchEnvironment["API_MODE"] = apiMode
        app.launchEnvironment["UITEST_VERBOSE_ERRORS"] = "true"
        if let apiBaseURL {
            app.launchEnvironment["API_BASE_URL"] = apiBaseURL
        }
        app.launchEnvironment["UITEST_ONBOARDING_COMPLETED"] = "true"
        app.launchEnvironment["UITEST_CLEAR_KEYCHAIN"] = "true"
        app.launch()
    }

    func testLoginScreenAppears() throws {
        XCTAssertTrue(app.navigationBars["Login"].waitForExistence(timeout: 5))
    }

    func testSignUpFlowReachesMainTabs() throws {
        app.buttons["login.createAccount"].tap()

        let emailField = app.textFields["signup.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(makeUniqueEmail())

        let passwordField = app.secureTextFields["signup.password"]
        passwordField.tap()
        passwordField.typeText("TestPass1234")

        let confirmField = app.secureTextFields["signup.confirmPassword"]
        confirmField.tap()
        confirmField.typeText("TestPass1234")
        dismissStrongPasswordPromptIfPresent()

        let submit = app.buttons["signup.submit"]
        XCTAssertTrue(waitForButtonEnabled(submit, timeout: 6), "Sign up submit should become enabled")
        submit.tap()
        assertReachedMainTabsAfterAuth(timeout: 15)
    }

    func testSignUpButtonDisabledWhenPasswordsMismatch() throws {
        app.buttons["login.createAccount"].tap()

        let emailField = app.textFields["signup.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(makeUniqueEmail())

        let passwordField = app.secureTextFields["signup.password"]
        passwordField.tap()
        passwordField.typeText("TestPass1234")

        let confirmField = app.secureTextFields["signup.confirmPassword"]
        confirmField.tap()
        confirmField.typeText("Mismatch1234")
        dismissStrongPasswordPromptIfPresent()

        XCTAssertFalse(app.buttons["signup.submit"].isEnabled)
    }

    func testChatStreamFlowWithMockAPI() throws {
        completeSignUpFlowIfNeeded()

        app.buttons["chat.newConversation"].tap()

        let input = app.textFields["chat.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("I feel dizzy when standing")
        app.buttons["chat.send"].tap()

        let assistantMessage = app.staticTexts["Assistant message"].firstMatch
        XCTAssertTrue(assistantMessage.waitForExistence(timeout: 20))
        let assistantValue = (assistantMessage.value as? String) ?? ""
        XCTAssertGreaterThan(assistantValue.count, 40)
        if apiMode == "mock" {
            let citation = app.buttons["Citation 1"]
            XCTAssertTrue(citation.waitForExistence(timeout: 6))
        }
    }

    func testV10EditFlowWithMockAPI() throws {
        completeSignUpFlowIfNeeded()

        app.tabBars.buttons["Health Profile"].tap()
        let setupButton = app.buttons["v10.setup"]
        let editButton = app.buttons["v10.edit"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 8) || editButton.waitForExistence(timeout: 8))
        if setupButton.exists {
            setupButton.tap()
        } else {
            editButton.tap()
        }

        let editor = app.textViews["v10.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Conditions: Hypertension")
        app.buttons["v10.save"].tap()

        XCTAssertTrue(app.staticTexts["Health profile saved."].waitForExistence(timeout: 8))
    }

    func testSettingsToggleFlowWithMockAPI() throws {
        completeSignUpFlowIfNeeded()

        app.tabBars.buttons["Settings"].tap()
        let highContrast = app.switches["settings.highContrast"]
        XCTAssertTrue(highContrast.waitForExistence(timeout: 5))

        let originalValue = highContrast.value as? String
        // Tap near the control knob to avoid tapping the row label area on some simulator builds.
        highContrast.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(waitForSwitchValueChange(highContrast, from: originalValue, timeout: 8))
    }

    private func completeSignUpFlowIfNeeded() {
        if app.tabBars.buttons["Chat"].exists {
            return
        }

        app.buttons["login.createAccount"].tap()

        let emailField = app.textFields["signup.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(makeUniqueEmail())

        let passwordField = app.secureTextFields["signup.password"]
        passwordField.tap()
        passwordField.typeText("TestPass1234")

        let confirmField = app.secureTextFields["signup.confirmPassword"]
        confirmField.tap()
        confirmField.typeText("TestPass1234")
        dismissStrongPasswordPromptIfPresent()

        let submit = app.buttons["signup.submit"]
        XCTAssertTrue(waitForButtonEnabled(submit, timeout: 6), "Sign up submit should become enabled")
        submit.tap()
        assertReachedMainTabsAfterAuth(timeout: 15)
    }

    private func makeUniqueEmail() -> String {
        if authMode == "firebase" {
            let millis = Int(Date().timeIntervalSince1970 * 1000)
            return "ui-live-\(millis)@medicare-test.com"
        }
        return "test@example.com"
    }

    private func waitForSwitchValueChange(
        _ toggle: XCUIElement,
        from originalValue: String?,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate { evaluated, _ in
            guard let element = evaluated as? XCUIElement else { return false }
            return (element.value as? String) != originalValue
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: toggle)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForButtonEnabled(_ button: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { evaluated, _ in
            guard let element = evaluated as? XCUIElement else { return false }
            return element.exists && element.isEnabled
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: button)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func dismissStrongPasswordPromptIfPresent() {
        let closeByLabel = app.buttons["Close"]
        if closeByLabel.waitForExistence(timeout: 1.5) {
            closeByLabel.tap()
            return
        }

        let closeByIdentifier = app.buttons["xmark"]
        if closeByIdentifier.waitForExistence(timeout: 1.0) {
            closeByIdentifier.tap()
        }
    }

    private func assertReachedMainTabsAfterAuth(
        timeout: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let chatTab = app.tabBars.buttons["Chat"]
        if chatTab.waitForExistence(timeout: timeout) {
            return
        }

        let possibleErrors = [
            "We could not create your account. Double-check your details and try again.",
            "That email and password do not match our records.",
            "We could not send a password reset email right now.",
            "The operation couldn’t be completed."
        ]

        let visibleError = possibleErrors.first { app.staticTexts[$0].exists } ?? "No known auth error text visible"
        let progressVisible = app.activityIndicators.firstMatch.exists
            || app.progressIndicators.firstMatch.exists
        let submitButton = app.buttons["signup.submit"]
        let submitEnabled = submitButton.exists ? submitButton.isEnabled : false
        let uiSnapshot = String(app.debugDescription.prefix(10000))
        XCTFail(
            "Did not reach authenticated tabs within \(Int(timeout))s. Visible error: \(visibleError). ProgressVisible=\(progressVisible). SignupSubmitEnabled=\(submitEnabled)\nUI Snapshot:\n\(uiSnapshot)",
            file: file,
            line: line
        )
    }
}
