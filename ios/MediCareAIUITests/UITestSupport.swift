import XCTest

extension XCUIApplication {
    /// The first element of any type with this accessibility identifier.
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// A mock-mode launch. `signedIn` starts as the sample account "Inge"; `seeded` adds
    /// sample chats and a health profile.
    static func mock(
        signedIn: Bool,
        seeded: Bool = false,
        locale: String = "en_US",
        colorScheme: String? = nil,
        onboardingDone: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", locale]
        app.launchEnvironment["AUTH_MODE"] = "mock"
        app.launchEnvironment["API_MODE"] = "mock"
        app.launchEnvironment["UITEST_VERBOSE_ERRORS"] = "true"
        app.launchEnvironment["UITEST_ONBOARDING_COMPLETED"] = onboardingDone ? "true" : "false"
        if signedIn {
            app.launchEnvironment["UITEST_SIGNED_IN"] = "true"
        } else {
            app.launchEnvironment["UITEST_CLEAR_KEYCHAIN"] = "true"
        }
        if seeded {
            app.launchEnvironment["UITEST_SEED_DATA"] = "true"
        }
        if let colorScheme {
            app.launchEnvironment["UITEST_COLOR_SCHEME"] = colorScheme
        }
        return app
    }

    /// Taps the navigation bar's back button.
    func goBack() {
        let named = navigationBars.buttons["BackButton"]
        if named.exists {
            named.tap()
        } else {
            navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    /// Types into a field, tapping it first.
    func type(_ text: String, into identifier: String, timeout: TimeInterval = 8) {
        let field = element(identifier)
        XCTAssertTrue(field.waitForExistence(timeout: timeout), "Missing field \(identifier)")
        field.tap()
        field.typeText(text)
    }
}

extension XCUIElement {
    /// Waits until the element exists and is enabled.
    func waitUntilEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { evaluated, _ in
            guard let element = evaluated as? XCUIElement else { return false }
            return element.exists && element.isEnabled
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits until the element is gone.
    func waitUntilGone(timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
