import SwiftUI
import XCTest
@testable import MediCareAI

final class AnswerLayoutTests: XCTestCase {
    private let sectioned = """
    Yes, for most people.
    Coffee won't stop metformin working [1]. Caffeine may raise your blood sugar a little [2].
    Do this:
    - Keep taking metformin with breakfast [3].
    - One or two cups a day, without sugar.
    Watch for:
    - A racing heart or upset stomach after coffee. Tell your doctor if it happens.
    """

    func testSectionedAnswerSplitsIntoParts() {
        let layout = AnswerLayout.parse(sectioned)
        XCTAssertEqual(layout.lead, "Yes, for most people.")
        XCTAssertEqual(
            layout.paragraphs,
            ["Coffee won't stop metformin working [1]. Caffeine may raise your blood sugar a little [2]."]
        )
        XCTAssertEqual(layout.doThis, ["Keep taking metformin with breakfast [3].", "One or two cups a day, without sugar."])
        XCTAssertEqual(layout.watchFor, ["A racing heart or upset stomach after coffee. Tell your doctor if it happens."])
    }

    func testOlderAnswerWithWhatToDoNextList() {
        let text = """
        Thanks for sharing that. Dizziness like this is often linked to dehydration [1].

        What to do next:
        - Drink water and rest.
        - Contact your doctor if symptoms continue.
        """
        let layout = AnswerLayout.parse(text)
        XCTAssertEqual(layout.lead, "Thanks for sharing that. Dizziness like this is often linked to dehydration [1].")
        XCTAssertEqual(layout.paragraphs, [])
        XCTAssertEqual(layout.doThis, ["Drink water and rest.", "Contact your doctor if symptoms continue."])
        XCTAssertEqual(layout.watchFor, [])
    }

    func testPlainAnswerKeepsEveryParagraph() {
        let text = "Hello! I can help with health questions."
        let layout = AnswerLayout.parse(text)
        XCTAssertNil(layout.lead)
        XCTAssertEqual(layout.paragraphs, [text])
        XCTAssertTrue(layout.doThis.isEmpty)
        XCTAssertTrue(layout.watchFor.isEmpty)
    }

    func testLongFirstParagraphIsNotTheShortAnswer() {
        let long = String(repeating: "Blood pressure changes during the day. ", count: 6)
        let layout = AnswerLayout.parse(long + "\nSecond paragraph.")
        XCTAssertNil(layout.lead)
        XCTAssertEqual(layout.paragraphs.count, 2)
    }

    func testBoldAndMarkdownHeadingsAreRecognised() {
        let layout = AnswerLayout.parse("Short answer.\n**Do this:**\n- Rest.\n### Watch for\n- Fever.")
        XCTAssertEqual(layout.lead, "Short answer.")
        XCTAssertEqual(layout.doThis, ["Rest."])
        XCTAssertEqual(layout.watchFor, ["Fever."])
    }

    func testHeadingWithTextOnTheSameLine() {
        let layout = AnswerLayout.parse("Yes.\nDo this: Drink water.")
        XCTAssertEqual(layout.lead, "Yes.")
        XCTAssertEqual(layout.doThis, ["Drink water."])
    }

    func testBulletsBeforeAnyHeadingStayInTheExplanation() {
        let layout = AnswerLayout.parse("Common causes:\n- Dehydration\n- Low blood pressure")
        XCTAssertNil(layout.lead)
        XCTAssertEqual(layout.paragraphs, ["Common causes:", "• Dehydration", "• Low blood pressure"])
    }

    func testPartialHeadingIsHeldBackWhileStreaming() {
        let layout = AnswerLayout.parse("Yes.\nCoffee is fine.\nDo th", isPartial: true)
        XCTAssertEqual(layout.lead, "Yes.")
        XCTAssertEqual(layout.paragraphs, ["Coffee is fine."])
        XCTAssertTrue(layout.doThis.isEmpty)
    }

    func testLoneBulletMarkerIsHeldBackWhileStreaming() {
        let layout = AnswerLayout.parse("Yes.\nDo this:\n-", isPartial: true)
        XCTAssertNil(layout.lead, "One piece of text is never the short answer")
        XCTAssertEqual(layout.paragraphs, ["Yes."])
        XCTAssertEqual(layout.doThis, [])
    }

    func testStreamingNeverLosesText() {
        var previous = 0
        for end in sectioned.indices {
            let prefix = String(sectioned[...end])
            let count = AnswerLayout.parse(prefix, isPartial: true).unitCount
            XCTAssertGreaterThanOrEqual(count, previous, "Shrank at: \(prefix.suffix(24))")
            previous = count
        }
        XCTAssertEqual(AnswerLayout.parse(sectioned).unitCount, 5)
    }

    // MARK: Text after the lists

    func testQuestionAfterTheListsIsNotAWarningSign() {
        let layout = AnswerLayout.parse(sectioned + "\nWould you like tips for a diabetes-friendly breakfast?")
        XCTAssertEqual(layout.watchFor, ["A racing heart or upset stomach after coffee. Tell your doctor if it happens."])
        XCTAssertEqual(layout.closing, ["Would you like tips for a diabetes-friendly breakfast?"])
    }

    func testOlderAnswerKeepsWarningsAndQuestionsOutOfDoThis() {
        let text = """
        Dizziness like this is often linked to dehydration [1].
        **What to do next:**
        1. Drink more water.
        2. Stand up slowly.
        **Seek immediate medical attention if:**
        - You faint or have chest pain.
        How long has this been happening?
        """
        let layout = AnswerLayout.parse(text)
        XCTAssertEqual(layout.lead, "Dizziness like this is often linked to dehydration [1].")
        XCTAssertEqual(layout.doThis, ["Drink more water.", "Stand up slowly."])
        XCTAssertEqual(layout.watchFor, ["You faint or have chest pain."])
        XCTAssertEqual(layout.closing, ["How long has this been happening?"])
    }

    func testCrisisLinesAfterTheListsStayOutOfTheBoxes() {
        let crisis = """

        If you are thinking about harming yourself, please reach out now:
        - In immediate danger: call your local emergency number (112 in Europe).
        - US: call or text 988 (Suicide & Crisis Lifeline).
        - Other countries: find a free, confidential helpline at https://findahelpline.com
        """
        let layout = AnswerLayout.parse(sectioned + crisis)
        XCTAssertEqual(layout.watchFor.count, 1)
        XCTAssertEqual(layout.closing, [
            "If you are thinking about harming yourself, please reach out now:",
            "• In immediate danger: call your local emergency number (112 in Europe).",
            "• US: call or text 988 (Suicide & Crisis Lifeline).",
            "• Other countries: find a free, confidential helpline at https://findahelpline.com",
        ])
    }

    func testUnknownHeadingAfterTheListsEndsTheBox() {
        let layout = AnswerLayout.parse("Yes.\nRest helps [1].\nDo this:\n- Rest.\n**Good to know**\nMost colds clear up in a week.")
        XCTAssertEqual(layout.doThis, ["Rest."])
        XCTAssertEqual(layout.closing, ["**Good to know**", "Most colds clear up in a week."])
    }

    func testMoreWaysToSayWatchFor() {
        let headings = [
            "Call your doctor if:", "See a doctor if:", "Seek immediate medical attention if:",
            "Red flags:", "When to seek emergency care:", "Go to the emergency room if:",
        ]
        for heading in headings {
            let layout = AnswerLayout.parse("Short answer.\n\(heading)\n- The fever lasts three days.")
            XCTAssertEqual(layout.watchFor, ["The fever lasts three days."], heading)
        }
    }

    func testHeadingsWithBackticksOrSingleStars() {
        let layout = AnswerLayout.parse("Yes.\nIt helps [1].\n`Do this:`\n- Rest.\n*Watch for:*\n- Fever.")
        XCTAssertEqual(layout.doThis, ["Rest."])
        XCTAssertEqual(layout.watchFor, ["Fever."])
    }

    // MARK: Streaming

    func testOneLineAnswerNeverStreamsAsTheShortAnswer() {
        let text = "You're very welcome! How are you feeling today?\n"
        for end in text.indices {
            XCTAssertNil(AnswerLayout.parse(String(text[...end]), isPartial: true).lead)
        }
        XCTAssertNil(AnswerLayout.parse(text).lead)
    }

    func testLongFirstLineNeverStreamsAsTheShortAnswer() {
        let text = String(repeating: "Blood pressure changes during the day. ", count: 6) + "\nCheck it at the same time."
        for end in text.indices {
            XCTAssertNil(AnswerLayout.parse(String(text[...end]), isPartial: true).lead)
        }
    }

    func testHalfFinishedBoldHeadingShowsNoStrayStar() {
        let layout = AnswerLayout.parse("Yes.\nCoffee is fine.\n**Do this:*", isPartial: true)
        XCTAssertEqual(layout.doThis, [])
    }

    func testStreamingShapeNeverGoesBackwards() {
        let samples = [
            sectioned,
            "Yes, for most people.\nCoffee is fine [1].\n**Do this:**\n- Rest.\n**Watch for:**\n- Fever.\nAnything else on your mind?",
            "Hello! I can help with health questions.",
        ]
        for sample in samples {
            var previous = AnswerLayout.parse("", isPartial: true)
            for end in sample.indices {
                let prefix = String(sample[...end])
                let layout = AnswerLayout.parse(prefix, isPartial: true)
                let at = "at: \(prefix.suffix(24))"
                if previous.lead != nil {
                    XCTAssertNotNil(layout.lead, "Lost the short answer \(at)")
                }
                XCTAssertGreaterThanOrEqual(layout.doThis.count, previous.doThis.count, "Do this shrank \(at)")
                XCTAssertGreaterThanOrEqual(layout.watchFor.count, previous.watchFor.count, "Watch for shrank \(at)")
                XCTAssertGreaterThanOrEqual(layout.unitCount, previous.unitCount, "Lost text \(at)")
                previous = layout
            }
            XCTAssertEqual(
                AnswerLayout.parse(sample, isPartial: true),
                AnswerLayout.parse(sample),
                "The last streamed layout should equal the final one"
            )
        }
    }
}

final class CitationTextTests: XCTestCase {
    func testMarkerBecomesACiteAndDropsTheSpaceBeforeIt() {
        XCTAssertEqual(CitationText.segments("Coffee works [1]."), [.text("Coffee works"), .cite(1), .text(".")])
    }

    func testGroupedMarkers() {
        XCTAssertEqual(CitationText.segments("A [1, 2] B"), [.text("A"), .cite(1), .cite(2), .text(" B")])
    }

    func testLinksAndIndexesAreLeftAlone() {
        let text = "See [the guide](https://nhs.uk) and x[0]"
        XCTAssertEqual(CitationText.segments(text), [.text(text)])
    }

    func testPlainRemovesMarkers() {
        XCTAssertEqual(CitationText.plain("Rest [1] and fluids [2]."), "Rest and fluids.")
    }
}

final class EmergencyNumberTests: XCTestCase {
    func testRegionalNumbers() {
        XCTAssertEqual(EmergencyNumber.number(forRegion: "DK"), "112")
        XCTAssertEqual(EmergencyNumber.number(forRegion: "US"), "911")
        XCTAssertEqual(EmergencyNumber.number(forRegion: "us"), "911")
        XCTAssertEqual(EmergencyNumber.number(forRegion: "GB"), "999")
        XCTAssertEqual(EmergencyNumber.number(forRegion: "AU"), "000")
        XCTAssertEqual(EmergencyNumber.number(forRegion: "NZ"), "111")
    }

    func testUnknownRegionFallsBackTo112() {
        XCTAssertEqual(EmergencyNumber.number(forRegion: nil), "112")
        XCTAssertEqual(EmergencyNumber.number(forRegion: "ZZ"), "112")
    }

    func testCountryName() {
        XCTAssertEqual(EmergencyNumber.countryName(forRegion: "DK"), "Denmark")
        XCTAssertNil(EmergencyNumber.countryName(forRegion: nil))
    }

    func testCountryPhraseReadsNaturallyAfterIn() {
        XCTAssertEqual(EmergencyNumber.countryPhrase(forRegion: "US"), "the United States")
        XCTAssertEqual(EmergencyNumber.countryPhrase(forRegion: "GB"), "the United Kingdom")
        XCTAssertEqual(EmergencyNumber.countryPhrase(forRegion: "NL"), "the Netherlands")
        XCTAssertEqual(EmergencyNumber.countryPhrase(forRegion: "DK"), "Denmark")
        XCTAssertNil(EmergencyNumber.countryPhrase(forRegion: nil))
    }
}

final class HealthProfileSectionsTests: XCTestCase {
    func testColonHeadingsAndBullets() {
        let digest = """
        Age/Demographics: 72
        Conditions:
        - Type 2 diabetes
        - High blood pressure
        Medications:
        - Metformin 500 mg, with breakfast
        Allergies: Penicillin
        Recent Concerns:
        - 2026-11-21: Dizzy spells in the morning
        """
        let sections = HealthProfileSections.parse(digest)
        XCTAssertEqual(sections.map(\.title), ["About you", "Conditions", "Medicines", "Allergies", "Recent concerns"])
        XCTAssertEqual(sections[0].items, ["72"])
        XCTAssertEqual(sections[1].items, ["Type 2 diabetes", "High blood pressure"])
        XCTAssertEqual(sections[2].items, ["Metformin 500 mg, with breakfast"])
        XCTAssertEqual(sections[3].items, ["Penicillin"])
        XCTAssertEqual(sections[4].items, ["2026-11-21: Dizzy spells in the morning"])
    }

    func testMarkdownHeadings() {
        let sections = HealthProfileSections.parse("## Allergies\n- Sulfa drugs\n## Medications\n- Lisinopril 10 mg")
        XCTAssertEqual(sections.map(\.kind), [.allergies, .medicines])
        XCTAssertEqual(sections[0].items, ["Sulfa drugs"])
        XCTAssertEqual(sections[1].items, ["Lisinopril 10 mg"])
    }

    func testTextWithoutHeadingsBecomesNotes() {
        let sections = HealthProfileSections.parse("Takes metformin daily.\nWalks every morning.")
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].title, "Notes")
        XCTAssertEqual(sections[0].items, ["Takes metformin daily.", "Walks every morning."])
    }

    func testOtherLanguagesKeepTheirOwnHeadings() {
        let sections = HealthProfileSections.parse("Medicin:\n- Metformin\nTilstande:\n- Diabetes")
        XCTAssertEqual(sections.map(\.title), ["Medicin", "Tilstande"])
        XCTAssertEqual(sections.map(\.kind), [.medicines, .other])
    }

    func testLabelledLinesStayAsWritten() {
        let digest = """
        Medications:
        - Metformin 500 mg
        Metformin dosage: 500 mg twice daily
        Recent HbA1c: 7.2%
        Drug interactions to avoid: grapefruit
        Family history: Heart disease, Diabetes
        """
        let sections = HealthProfileSections.parse(digest)
        XCTAssertEqual(sections.map(\.title), ["Medicines"])
        XCTAssertEqual(sections.first?.items, [
            "Metformin 500 mg",
            "Metformin dosage: 500 mg twice daily",
            "Recent HbA1c: 7.2%",
            "Drug interactions to avoid: grapefruit",
            "Family history: Heart disease, Diabetes",
        ])
    }

    func testBoldHeadingsWithoutAColon() {
        let sections = HealthProfileSections.parse("**Conditions**\n- Asthma\n**Medications**\n- Salbutamol inhaler")
        XCTAssertEqual(sections.map(\.title), ["Conditions", "Medicines"])
        XCTAssertEqual(sections.last?.items, ["Salbutamol inhaler"])
    }

    func testAgeMatchesOnlyAsAWholeWord() {
        let sections = HealthProfileSections.parse("Dosage notes:\n- Half a tablet at night")
        XCTAssertEqual(sections.map(\.title), ["Dosage notes"])
        XCTAssertEqual(sections.map(\.kind), [.other])
    }

    func testSameHeadingTwiceMakesOneCardWithUniqueIDs() {
        let sections = HealthProfileSections.parse("Medications:\n- Metformin\nSupplements:\n- Vitamin D\nMedications:\n- Amlodipine")
        XCTAssertEqual(sections.map(\.title), ["Medicines", "Supplements"])
        XCTAssertEqual(sections.first?.items, ["Metformin", "Amlodipine"])
        XCTAssertEqual(Set(sections.map(\.id)).count, sections.count)
    }

    func testEmptyDigest() {
        XCTAssertEqual(HealthProfileSections.parse("  \n "), [])
    }
}

final class GreetingTests: XCTestCase {
    func testTimeOfDay() {
        XCTAssertEqual(Greeting.text(hour: 9, firstName: "Inge"), "Good morning, Inge")
        XCTAssertEqual(Greeting.text(hour: 14, firstName: "Inge"), "Good afternoon, Inge")
        XCTAssertEqual(Greeting.text(hour: 20, firstName: "Inge"), "Good evening, Inge")
        XCTAssertEqual(Greeting.text(hour: 2, firstName: nil), "Good evening")
    }

    func testNameIsFirstWordCapitalised() {
        XCTAssertEqual(Greeting.text(hour: 9, firstName: "  inge marie "), "Good morning, Inge")
        XCTAssertEqual(Greeting.text(hour: 9, firstName: "   "), "Good morning")
    }

    func testNameStoreIsPerAccount() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "NameStoreTests-\(UUID().uuidString)"))
        NameStore.setFirstName("Inge", for: "uid-a", defaults: defaults)
        XCTAssertEqual(NameStore.firstName(for: "uid-a", defaults: defaults), "Inge")
        XCTAssertNil(NameStore.firstName(for: "uid-b", defaults: defaults))
        NameStore.setFirstName(nil, for: "uid-a", defaults: defaults)
        XCTAssertNil(NameStore.firstName(for: "uid-a", defaults: defaults))
    }
}

final class SpeechTextTests: XCTestCase {
    func testReadAloudTextHasNoMarkersOrMarkdown() {
        let answer = """
        Yes, for most people.
        Coffee won't stop **metformin** working [1].
        Do this:
        - Keep taking it with breakfast [3]
        Watch for:
        - A racing heart
        """
        XCTAssertEqual(
            SpeechText.plain(from: answer),
            "Yes, for most people. Coffee won't stop metformin working. Do this. Keep taking it with breakfast. "
                + "Watch for. A racing heart."
        )
    }
}

final class SourceNameTests: XCTestCase {
    func testKnownPublishers() {
        XCTAssertEqual(SourceName.display(for: "mayoclinic.org"), "Mayo Clinic")
        XCTAssertEqual(SourceName.display(for: "www.nhs.uk"), "NHS")
        XCTAssertEqual(SourceName.display(for: "cks.nice.org.uk"), "NICE")
        XCTAssertEqual(SourceName.display(for: "pubmed.ncbi.nlm.nih.gov"), "PubMed")
        XCTAssertEqual(SourceName.display(for: "ncbi.nlm.nih.gov"), "NIH")
    }

    func testUnknownHostsAndNamesPassThrough() {
        XCTAssertEqual(SourceName.display(for: "example.com"), "example.com")
        XCTAssertEqual(SourceName.display(for: "Mayo Clinic"), "Mayo Clinic")
    }
}

final class EmergencySpeechTests: XCTestCase {
    func testEmergencyAnswerIsReadWithTheCallFirst() {
        XCTAssertEqual(
            SpeechText.emergencyIntro(number: "112"),
            "This could be an emergency. Call 112 now. Don't wait to see if it gets better."
        )
        let message = Message(
            id: "m1", role: .assistant, content: "Sit down and rest.", citations: [], confidence: nil,
            requiresEmergencyCare: true, createdAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(
            SpeechText.forMessage(message, emergencyNumber: "112"),
            "This could be an emergency. Call 112 now. Don't wait to see if it gets better. Sit down and rest."
        )
    }

    func testOrdinaryAnswerIsReadAsWritten() {
        let message = Message(
            id: "m1", role: .assistant, content: "Rest helps.", citations: [], confidence: nil,
            requiresEmergencyCare: false, createdAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(SpeechText.forMessage(message, emergencyNumber: "112"), "Rest helps.")
    }

    /// Guard: text after the lists is still read, at the end.
    func testClosingTextIsReadLast() {
        let text = SpeechText.plain(from: "Yes.\nIt helps.\nDo this:\n- Rest.\nWatch for:\n- Fever.\nAnything else?")
        XCTAssertTrue(text.hasSuffix("Fever. Anything else?"), text)
    }
}

@MainActor
final class AnswerTextTests: XCTestCase {
    func testBoldAcrossASourceNumberShowsNoStars() {
        let text = AnswerText.attributed("**Take it with food [1] every day.**")
        XCTAssertFalse(String(text.characters).contains("*"), String(text.characters))
        XCTAssertTrue(text.runs.contains { $0.link == URL(string: "medicare-cite://1") })
        let bold = text.runs.filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
        XCTAssertTrue(bold.contains { String(text[$0.range].characters).contains("every day") })
    }

    func testSourceNumbersStillOpenTheirSource() {
        let text = AnswerText.attributed("Rest helps [1, 2].")
        let links = text.runs.compactMap { $0.link }
        XCTAssertEqual(links, [URL(string: "medicare-cite://1"), URL(string: "medicare-cite://2")].compactMap { $0 })
    }
}

final class TranscriptGateTests: XCTestCase {
    func testResultsAfterStopAreIgnored() {
        var gate = TranscriptGate()
        let session = gate.open()
        XCTAssertTrue(gate.accepts(session))
        gate.close()
        XCTAssertFalse(gate.accepts(session))
    }

    func testResultsFromAnEarlierSessionAreIgnored() {
        var gate = TranscriptGate()
        let first = gate.open()
        gate.close()
        let second = gate.open()
        XCTAssertFalse(gate.accepts(first))
        XCTAssertTrue(gate.accepts(second))
    }
}

@MainActor
final class ChatScreenTests: XCTestCase {
    func testQuestionFromHomeSkipsTheWelcome() {
        XCTAssertFalse(ChatView.showsWelcome(conversation: nil, starter: .question("Is coffee okay?"), isEmpty: true))
        XCTAssertTrue(ChatView.showsWelcome(conversation: nil, starter: .topic(.medicines), isEmpty: true))
        XCTAssertTrue(ChatView.showsWelcome(conversation: nil, starter: nil, isEmpty: true))
        XCTAssertFalse(ChatView.showsWelcome(conversation: nil, starter: nil, isEmpty: false))
    }

    func testFinishedAnswerIsOnlyRedrawnWhenItChanges() {
        let message = Message(
            id: "m1", role: .assistant, content: "Yes.", citations: [], confidence: nil,
            requiresEmergencyCare: false, createdAt: Date(timeIntervalSince1970: 0)
        )
        let edited = Message(
            id: "m1", role: .assistant, content: "No.", citations: [], confidence: nil,
            requiresEmergencyCare: false, createdAt: Date(timeIntervalSince1970: 0)
        )
        let first = AnswerView(message: message, onCitation: { _ in })
        let again = AnswerView(message: message, onCitation: { _ in })
        let changed = AnswerView(message: edited, onCitation: { _ in })
        XCTAssertTrue(first == again)
        XCTAssertFalse(first == changed)
    }
}

final class TextSizePreferenceTests: XCTestCase {
    func testOnlyExtraLargeRaisesTheMinimum() {
        XCTAssertNil(UserSettings.FontSize.regular.minimumDynamicType)
        XCTAssertNil(UserSettings.FontSize.large.minimumDynamicType)
        XCTAssertEqual(UserSettings.FontSize.extraLarge.minimumDynamicType, .accessibility1)
    }
}
