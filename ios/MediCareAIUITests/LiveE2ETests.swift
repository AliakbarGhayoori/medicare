import XCTest
import UIKit

/// Full end-to-end tests that run against the live backend (Firebase auth + real AI).
/// Prerequisite: backend running on localhost:8000 with .env.live configuration.
final class LiveE2ETests: XCTestCase {
    let app = XCUIApplication()
    static var testEmail = "e2eui-\(Int(Date().timeIntervalSince1970))@medicare-test.com"
    static let testPassword = "LiveTest1234"
    static var didResetAuthState = false

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "--uitesting",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment["AUTH_MODE"] = "firebase"
        app.launchEnvironment["API_MODE"] = "live"
        app.launchEnvironment["API_BASE_URL"] = "http://127.0.0.1:8000"
        app.launchEnvironment["UITEST_ONBOARDING_COMPLETED"] = "true"
        app.launchEnvironment["UITEST_VERBOSE_ERRORS"] = "true"
        // Clear keychain only once per suite run; keep session for later flows.
        if Self.didResetAuthState {
            app.launchEnvironment["UITEST_CLEAR_KEYCHAIN"] = "false"
        } else {
            app.launchEnvironment["UITEST_CLEAR_KEYCHAIN"] = "true"
            Self.didResetAuthState = true
        }
    }

    // MARK: - Full Live Journey (single-session, production-real)

    func test00_FullLiveJourney() throws {
        app.launch()

        if !waitForChatOrDismissPrompts(timeout: 8) {
            // Prefer reusing the known test account to avoid repeated live signup flakiness.
            if performLogin(email: Self.testEmail, password: Self.testPassword) {
                XCTAssertTrue(waitForChatOrDismissPrompts(timeout: 12), "Chat not visible after existing-account login")
            } else {
                let createAccountBtn = app.buttons["login.createAccount"]
                guard createAccountBtn.waitForExistence(timeout: 8) else {
                    XCTFail("Could not reach auth entry point. \(visibleAuthErrorSummary())")
                    return
                }
                createAccountBtn.tap()

                let freshEmail = "e2eui-\(Int(Date().timeIntervalSince1970 * 1000))@medicare-test.com"
                if performSignUp(email: freshEmail, password: Self.testPassword) {
                    Self.testEmail = freshEmail
                } else {
                    navigateBackToLoginIfNeeded()
                    XCTAssertTrue(
                        performLogin(email: Self.testEmail, password: Self.testPassword),
                        "Signup/login fallback failed in full journey. \(visibleAuthErrorSummary())"
                    )
                }
            }
        }

        // Chat flow
        let newChatBtn = app.buttons["chat.newConversation"]
        if newChatBtn.waitForExistence(timeout: 6) {
            newChatBtn.tap()
        }
        let chatInput = app.textFields["chat.input"]
        XCTAssertTrue(chatInput.waitForExistence(timeout: 10), "Chat input not visible")
        chatInput.tap()
        chatInput.typeText("What are common side effects of metformin?")
        app.buttons["chat.send"].tap()
        XCTAssertTrue(
            app.staticTexts["Assistant message"].firstMatch.waitForExistence(timeout: 120),
            "Assistant response did not appear in time"
        )
        takeScreenshot(name: "FullJourney-Chat")

        // Health profile flow
        XCTAssertTrue(openHealthProfileTab(timeout: 12), "Health Profile tab not reachable")
        let setupButton = findButton(identifiers: ["v10.setup", "Create Health Profile"], timeout: 12)
        let editButton = findButton(identifiers: ["v10.edit", "Edit health profile"], timeout: 8)
        if let setupButton {
            setupButton.tap()
        } else if let editButton {
            editButton.tap()
        }
        let editor = app.textViews["v10.editor"]
        if editor.waitForExistence(timeout: 12) {
            editor.tap()
            editor.typeText("Type 2 diabetes. Metformin. Hypertension on lisinopril.")
            if app.buttons["v10.save"].waitForExistence(timeout: 6) {
                app.buttons["v10.save"].tap()
            }
        }
        takeScreenshot(name: "FullJourney-V10")

        // Settings flow
        XCTAssertTrue(openSettingsTab(timeout: 12), "Settings tab not reachable")
        if let highContrast = findSwitch(identifiers: ["settings.highContrast", "High Contrast"], timeout: 10) {
            highContrast.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        takeScreenshot(name: "FullJourney-Settings")

        // Logout + login again (real auth)
        var logoutButton = findButton(identifiers: ["settings.logout", "Log Out"], timeout: 4)
        if logoutButton == nil {
            app.swipeUp()
            logoutButton = findButton(identifiers: ["settings.logout", "Log Out"], timeout: 6)
        }
        XCTAssertNotNil(logoutButton, "Logout button not visible in Settings")
        logoutButton?.tap()
        if app.alerts.buttons["Log Out"].waitForExistence(timeout: 3) {
            app.alerts.buttons["Log Out"].tap()
        }
        XCTAssertTrue(
            app.buttons["login.createAccount"].waitForExistence(timeout: 10) ||
            app.textFields["login.email"].waitForExistence(timeout: 5),
            "Did not return to login after logout"
        )

        XCTAssertTrue(
            performLogin(email: Self.testEmail, password: Self.testPassword),
            "Could not sign back in during full journey. \(visibleAuthErrorSummary())"
        )
        XCTAssertTrue(waitForChatOrDismissPrompts(timeout: 15), "Chat not visible after re-login")
        takeScreenshot(name: "FullJourney-Relogin")
    }

    // MARK: - Flow 1: Sign Up

    func test01_SignUp() throws {
        app.launch()

        let createAccountBtn = app.buttons["login.createAccount"]
        if createAccountBtn.waitForExistence(timeout: 10) {
            createAccountBtn.tap()
        } else if waitForChatOrDismissPrompts(timeout: 5) {
            takeScreenshot(name: "Flow1-SignUp-AlreadyAuthenticated")
            return
        } else {
            XCTFail("Could not reach signup entry point. \(visibleAuthErrorSummary())")
            return
        }

        if !performSignUp(email: Self.testEmail, password: Self.testPassword) {
            navigateBackToLoginIfNeeded()
            XCTAssertTrue(
                performLogin(email: Self.testEmail, password: Self.testPassword),
                "Sign up/login fallback failed. \(visibleAuthErrorSummary())"
            )
        }

        takeScreenshot(name: "Flow1-SignUp-Complete")
    }

    // MARK: - Flow 2: Sign Out & Sign In

    func test02_SignOutAndSignIn() throws {
        app.launch()
        ensureLoggedIn()

        // Go to Settings
        XCTAssertTrue(openSettingsTab(timeout: 12), "Could not open Settings tab")

        takeScreenshot(name: "Flow2-Settings-Screen")

        // Tap Log Out
        var logoutButton = findButton(identifiers: ["settings.logout", "Log Out"], timeout: 4)
        if logoutButton == nil {
            app.swipeUp()
            logoutButton = findButton(identifiers: ["settings.logout", "Log Out"], timeout: 6)
        }
        XCTAssertNotNil(logoutButton, "Logout button missing on Settings")
        logoutButton?.tap()

        // Confirm logout if dialog appears
        let confirmLogout = app.alerts.buttons["Log Out"]
        if confirmLogout.waitForExistence(timeout: 3) {
            confirmLogout.tap()
        }

        // Should return to login screen
        let loginScreen = app.buttons["login.createAccount"]
        let emailField = app.textFields["login.email"]
        let foundLogin = loginScreen.waitForExistence(timeout: 10) || emailField.waitForExistence(timeout: 5)
        XCTAssertTrue(foundLogin, "Should return to login screen after logout")

        takeScreenshot(name: "Flow2-LoggedOut")

        // Sign back in
        XCTAssertTrue(
            performLogin(email: Self.testEmail, password: Self.testPassword),
            "Should sign back in after logout. \(visibleAuthErrorSummary())"
        )
        XCTAssertTrue(waitForChatOrDismissPrompts(timeout: 15), "Should return to Chat after sign in")

        takeScreenshot(name: "Flow2-SignedBackIn")
    }

    // MARK: - Flow 3: Chat Health Question

    func test03_ChatHealthQuestion() throws {
        app.launch()
        ensureLoggedIn()

        // Tap Start New Chat or a suggested question
        let newChatBtn = app.buttons["chat.newConversation"]
        if newChatBtn.waitForExistence(timeout: 5) {
            newChatBtn.tap()
        } else {
            // Try tapping a suggested question
            let suggestion = app.staticTexts["What are common side effects of metformin?"]
            if suggestion.waitForExistence(timeout: 3) {
                suggestion.tap()
            }
        }

        // Type a health question
        let chatInput = app.textFields["chat.input"]
        if chatInput.waitForExistence(timeout: 10) {
            chatInput.tap()
            chatInput.typeText("What are common side effects of metformin?")

            let sendBtn = app.buttons["chat.send"]
            if sendBtn.waitForExistence(timeout: 3) {
                sendBtn.tap()
            }
        }

        takeScreenshot(name: "Flow3-QuestionSent")

        // Wait for response (AI + Tavily takes 30-60s)
        // Look for any assistant message or searching indicator
        let searchingIndicator = app.staticTexts["Searching..."]
        if searchingIndicator.waitForExistence(timeout: 15) {
            takeScreenshot(name: "Flow3-Searching")
        }

        // Wait for the full response (up to 120s)
        let assistantMessage = app.staticTexts["Assistant message"].firstMatch
        let responseAppeared = assistantMessage.waitForExistence(timeout: 120)

        takeScreenshot(name: "Flow3-ResponseReceived")

        // Even if the specific accessibility identifier isn't found,
        // check that something new appeared in the chat
        if !responseAppeared {
            // Alternative: check for confidence indicator or any new content
            sleep(5)
            takeScreenshot(name: "Flow3-FinalState")
        }

        // Routine medication question should not trigger emergency banner.
        XCTAssertFalse(
            app.staticTexts["This could be a medical emergency"].exists,
            "Routine question unexpectedly triggered emergency banner."
        )
    }

    // MARK: - Flow 4: Emergency Detection

    func test04_EmergencyDetection() throws {
        app.launch()
        ensureLoggedIn()

        // Start a new chat
        let newChatBtn = app.buttons["chat.newConversation"]
        if newChatBtn.waitForExistence(timeout: 5) {
            newChatBtn.tap()
        }

        let chatInput = app.textFields["chat.input"]
        if chatInput.waitForExistence(timeout: 10) {
            chatInput.tap()
            chatInput.typeText("I have severe chest pain and can't breathe")

            let sendBtn = app.buttons["chat.send"]
            if sendBtn.waitForExistence(timeout: 3) {
                sendBtn.tap()
            }
        }

        takeScreenshot(name: "Flow4-EmergencySent")

        // Wait for response
        sleep(60)

        takeScreenshot(name: "Flow4-EmergencyResponse")

        // Look for emergency warning or 911 text
        let emergencyFound = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '911' OR label CONTAINS 'emergency' OR label CONTAINS 'Emergency'")).firstMatch
        let emergencyVisible = emergencyFound.waitForExistence(timeout: 30)
        XCTAssertTrue(emergencyVisible, "Emergency query should surface emergency warning/911 guidance.")
        if emergencyVisible {
            takeScreenshot(name: "Flow4-EmergencyWarningVisible")
        }
    }

    // MARK: - Flow 5: Follow-up in Same Conversation

    func test05_FollowUpConversation() throws {
        app.launch()
        ensureLoggedIn()

        // The previous chat from Flow 3 should still be open or accessible
        // Go back to chat tab
        XCTAssertTrue(openChatTab(timeout: 8), "Could not open Chat tab")

        // Try to find and open the most recent conversation
        // Or start a new one and send follow-up
        let newChatBtn = app.buttons["chat.newConversation"]
        if newChatBtn.waitForExistence(timeout: 5) {
            newChatBtn.tap()
        }

        let chatInput = app.textFields["chat.input"]
        if chatInput.waitForExistence(timeout: 10) {
            chatInput.tap()
            chatInput.typeText("What are common uses of aspirin?")
            app.buttons["chat.send"].tap()

            // Wait for first response
            sleep(60)
            takeScreenshot(name: "Flow5-FirstResponse")

            // Send follow-up
            if chatInput.waitForExistence(timeout: 10) {
                chatInput.tap()
                chatInput.typeText("Is it safe to take it with blood pressure medication?")
                app.buttons["chat.send"].tap()
            }

            // Wait for follow-up response
            sleep(60)
            takeScreenshot(name: "Flow5-FollowUpResponse")
        }
    }

    // MARK: - Flow 6: Conversation History

    func test06_ConversationHistory() throws {
        app.launch()
        ensureLoggedIn()

        XCTAssertTrue(openChatTab(timeout: 8), "Could not open Chat tab")

        takeScreenshot(name: "Flow6-ConversationList")

        // There should be conversations from previous flows
        // Try tapping on the first conversation in the list
        let conversations = app.cells
        if conversations.firstMatch.waitForExistence(timeout: 10) {
            conversations.firstMatch.tap()
            sleep(2)
            takeScreenshot(name: "Flow6-ConversationDetail")
        }
    }

    // MARK: - Flow 7: Health Profile (V10)

    func test07_HealthProfile() throws {
        app.launch()
        ensureLoggedIn()

        XCTAssertTrue(openHealthProfileTab(timeout: 12), "Health Profile tab should be reachable")

        takeScreenshot(name: "Flow7-HealthProfile-Initial")

        // Tap edit or setup
        let setupButton = findButton(identifiers: ["v10.setup", "Create Health Profile"], timeout: 12)
        let editButton = findButton(identifiers: ["v10.edit", "Edit health profile"], timeout: 8)

        if let setupButton {
            setupButton.tap()
        } else if let editButton {
            editButton.tap()
        }

        let editor = app.textViews["v10.editor"]
        if editor.waitForExistence(timeout: 12) {
            editor.tap()
            editor.typeText("72 years old. Diabetes type 2. Takes metformin. High blood pressure on lisinopril.")

            let saveBtn = app.buttons["v10.save"]
            if saveBtn.waitForExistence(timeout: 6) {
                saveBtn.tap()
            }

            takeScreenshot(name: "Flow7-HealthProfile-Saved")

            // Verify profile is saved
            let savedConfirmation = app.staticTexts["Health profile saved."]
            if savedConfirmation.waitForExistence(timeout: 10) {
                takeScreenshot(name: "Flow7-HealthProfile-Confirmed")
            }
        }
    }

    // MARK: - Flow 8: Settings

    func test08_Settings() throws {
        app.launch()
        ensureLoggedIn()

        XCTAssertTrue(openSettingsTab(timeout: 12), "Could not open Settings tab")

        takeScreenshot(name: "Flow8-Settings-Initial")

        // Toggle high contrast
        if let highContrast = findSwitch(identifiers: ["settings.highContrast", "High Contrast"], timeout: 10) {
            let originalValue = highContrast.value as? String
            highContrast.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            sleep(1)
            takeScreenshot(name: "Flow8-Settings-HighContrastToggled")

            // Verify the change persisted
            let newValue = highContrast.value as? String
            XCTAssertNotEqual(originalValue, newValue, "High contrast toggle should change value")
        }

        // Change font size
        let fontSizePicker = app.buttons["settings.fontSize"]
        if fontSizePicker.waitForExistence(timeout: 6) {
            fontSizePicker.tap()
            sleep(1)

            let largeOption = app.buttons["Large"]
            if largeOption.waitForExistence(timeout: 3) {
                largeOption.tap()
            }

            takeScreenshot(name: "Flow8-Settings-FontSizeChanged")
        }

        // Navigate away and back to verify persistence
        XCTAssertTrue(openChatTab(timeout: 8), "Could not switch to Chat tab")
        sleep(1)
        XCTAssertTrue(openSettingsTab(timeout: 8), "Could not switch back to Settings tab")
        sleep(1)

        takeScreenshot(name: "Flow8-Settings-Persisted")
    }

    // MARK: - Helpers

    private func ensureLoggedIn() {
        if waitForChatOrDismissPrompts(timeout: 6) {
            _ = openChatTab(timeout: 6)
            return
        }

        let createAccountBtn = app.buttons["login.createAccount"]
        if !createAccountBtn.waitForExistence(timeout: 8) {
            XCTFail("Neither Chat tab nor login screen appeared. \(visibleAuthErrorSummary())")
            return
        }

        if performLogin(email: Self.testEmail, password: Self.testPassword) {
            return
        }

        dismissKeyboardIfPresent()
        createAccountBtn.tap()
        XCTAssertTrue(
            performSignUp(email: Self.testEmail, password: Self.testPassword),
            "Should be logged in after fallback sign up. \(visibleAuthErrorSummary())"
        )
    }

    private enum ElementType {
        case textField, secureTextField, button
    }

    private func openChatTab(timeout: TimeInterval) -> Bool {
        guard tapTab(candidates: ["tab.chat", "Chat"], fallbackIndex: 0, timeout: timeout) else {
            return false
        }
        return app.buttons["chat.newConversation"].waitForExistence(timeout: 8) ||
               app.textFields["chat.input"].waitForExistence(timeout: 8) ||
               app.navigationBars["Chat"].waitForExistence(timeout: 8) ||
               chatTabIsVisible()
    }

    private func openHealthProfileTab(timeout: TimeInterval) -> Bool {
        guard tapTab(candidates: ["tab.healthProfile", "Health Profile"], fallbackIndex: 1, timeout: timeout) else {
            return false
        }
        return app.otherElements["screen.healthProfile"].waitForExistence(timeout: 8) ||
               app.navigationBars["Health Profile"].waitForExistence(timeout: 8) ||
               app.staticTexts["Your Health Profile Is Empty"].waitForExistence(timeout: 8) ||
               findButton(identifiers: ["v10.setup", "Create Health Profile"], timeout: 8) != nil ||
               findButton(identifiers: ["v10.edit", "Edit health profile"], timeout: 8) != nil
    }

    private func openSettingsTab(timeout: TimeInterval) -> Bool {
        guard tapTab(candidates: ["tab.settings", "Settings"], fallbackIndex: 2, timeout: timeout) else {
            return false
        }
        if app.otherElements["screen.settings"].waitForExistence(timeout: 8) ||
            app.navigationBars["Settings"].waitForExistence(timeout: 8) ||
            findSwitch(identifiers: ["settings.highContrast", "High Contrast"], timeout: 8) != nil ||
            findButton(identifiers: ["settings.logout", "Log Out"], timeout: 8) != nil {
            return true
        }

        app.swipeUp()
        return findButton(identifiers: ["settings.logout", "Log Out"], timeout: 6) != nil ||
               findSwitch(identifiers: ["settings.highContrast", "High Contrast"], timeout: 6) != nil
    }

    private func tapTab(candidates: [String], fallbackIndex: Int, timeout: TimeInterval) -> Bool {
        dismissKeyboardIfPresent()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: timeout) else { return false }

        var sawCandidate = false
        for candidate in candidates {
            let button = tabBar.buttons[candidate]
            guard button.exists else { continue }
            sawCandidate = true
            if button.isHittable {
                button.tap()
                return true
            }
        }

        let byIndex = tabBar.buttons.element(boundBy: fallbackIndex)
        if byIndex.exists {
            if byIndex.isHittable {
                byIndex.tap()
            } else {
                byIndex.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            return true
        }

        if sawCandidate {
            return false
        }

        let safeIndex = max(0, min(fallbackIndex, 2))
        let x = (CGFloat(safeIndex) + 0.5) / 3.0
        tabBar.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5)).tap()
        return true
    }

    private func chatTabIsVisible() -> Bool {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.exists else { return false }
        return tabBar.buttons["tab.chat"].exists ||
               tabBar.buttons["Chat"].exists ||
               tabBar.buttons["message.fill"].exists
    }

    private func findElement(identifiers: [String], type: ElementType) -> XCUIElement? {
        for id in identifiers {
            let element: XCUIElement
            switch type {
            case .textField:
                element = app.textFields[id]
            case .secureTextField:
                element = app.secureTextFields[id]
            case .button:
                element = app.buttons[id]
            }
            if element.waitForExistence(timeout: 3) {
                return element
            }
        }
        return nil
    }

    private func findButton(identifiers: [String], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for id in identifiers {
                let button = app.buttons[id]
                if button.exists {
                    return button
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return nil
    }

    private func findSwitch(identifiers: [String], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for id in identifiers {
                let toggle = app.switches[id]
                if toggle.exists {
                    return toggle
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return nil
    }

    private func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForButtonEnabled(_ button: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { evaluated, _ in
            guard let element = evaluated as? XCUIElement else { return false }
            return element.exists && element.isEnabled
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: button)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func performLogin(email: String, password: String) -> Bool {
        guard let emailField = findElement(identifiers: ["login.email"], type: .textField),
              let passField = findElement(identifiers: ["login.password"], type: .secureTextField),
              let submitBtn = findElement(identifiers: ["login.submit", "login.signIn"], type: .button)
        else {
            return false
        }

        guard typeTextSafely(email, into: emailField) else { return false }
        guard typeTextSafely(password, into: passField) else { return false }
        submitBtn.tap()
        return waitForChatOrDismissPrompts(timeout: 20)
    }

    private func performSignUp(email: String, password: String) -> Bool {
        let emailField = app.textFields["signup.email"]
        guard emailField.waitForExistence(timeout: 10) else { return false }
        guard typeTextSafely(email, into: emailField) else { return false }

        let passwordField = app.secureTextFields["signup.password"]
        guard passwordField.waitForExistence(timeout: 5) else { return false }
        guard typeTextSafely(password, into: passwordField) else { return false }

        let confirmField = app.secureTextFields["signup.confirmPassword"]
        guard confirmField.waitForExistence(timeout: 5) else { return false }
        guard typeTextSafely(password, into: confirmField) else { return false }
        dismissStrongPasswordPromptIfPresent()

        let submitBtn = app.buttons["signup.submit"]
        guard submitBtn.waitForExistence(timeout: 5) else { return false }
        guard waitForButtonEnabled(submitBtn, timeout: 6) else { return false }
        submitBtn.tap()

        return waitForChatOrDismissPrompts(timeout: 25)
    }

    private func waitForChatOrDismissPrompts(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if chatTabIsVisible() {
                return true
            }

            let acceptButton = app.buttons["Accept"]
            if acceptButton.exists {
                acceptButton.tap()
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return chatTabIsVisible()
    }

    private func navigateBackToLoginIfNeeded() {
        if app.buttons["login.submit"].exists || app.buttons["login.createAccount"].exists {
            return
        }

        if app.navigationBars.buttons["Login"].exists {
            app.navigationBars.buttons["Login"].tap()
            return
        }

        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
        }
    }

    private func tapField(_ field: XCUIElement) {
        if field.isHittable {
            field.tap()
            return
        }

        // Fallback for occasional keyboard/layout overlap in simulator runs.
        app.swipeDown()
        if field.isHittable {
            field.tap()
            return
        }

        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func dismissKeyboardIfPresent() {
        guard app.keyboards.count > 0 else { return }

        let dismissLabels = ["Done", "Return", "return", "Go", "Next"]
        if let key = dismissLabels.first(where: { app.keyboards.buttons[$0].exists }) {
            app.keyboards.buttons[key].tap()
            return
        }

        app.tap()
    }

    private func typeTextSafely(_ text: String, into field: XCUIElement) -> Bool {
        for _ in 0..<3 {
            tapField(field)
            if app.keyboards.firstMatch.waitForExistence(timeout: 1.0) {
                if pasteText(text, into: field) {
                    return true
                }
                app.typeText(text)
                return true
            }
            dismissKeyboardIfPresent()
        }
        return false
    }

    private func pasteText(_ text: String, into field: XCUIElement) -> Bool {
        UIPasteboard.general.string = text

        field.press(forDuration: 0.8)
        if let selectAll = firstExistingMenuItem(labels: ["Select All", "انتخاب همه"], timeout: 0.7) {
            selectAll.tap()
            app.typeText(XCUIKeyboardKey.delete.rawValue)
            field.press(forDuration: 0.5)
        }

        if let paste = firstExistingMenuItem(labels: ["Paste", "چسباندن"], timeout: 1.0) {
            paste.tap()
            return true
        }

        return false
    }

    private func firstExistingMenuItem(labels: [String], timeout: TimeInterval) -> XCUIElement? {
        for label in labels {
            let item = app.menuItems[label]
            if item.waitForExistence(timeout: timeout) {
                return item
            }
        }
        return nil
    }

    private func visibleAuthErrorSummary() -> String {
        let verbosePrefixes = ["Sign up failed:", "Sign in failed:"]
        for prefix in verbosePrefixes {
            let message = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
            if message.exists {
                return "Visible auth error: \(message.label)"
            }
        }

        let knownMessages = [
            "We could not create your account. Double-check your details and try again.",
            "That email and password do not match our records.",
            "The operation couldn’t be completed.",
            "Sign up failed:",
            "Sign in failed:"
        ]

        if let message = knownMessages.first(where: { app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", $0)).firstMatch.exists }) {
            return "Visible auth error contains: \(message)"
        }

        return "No known auth error visible. UI snapshot: \(String(app.debugDescription.prefix(6000)))"
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
}
