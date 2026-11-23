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
        XCTAssertEqual(layout.lead, "Yes.")
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

    func testOtherLanguagesStillShowSomething() {
        let sections = HealthProfileSections.parse("Medicin:\n- Metformin\nTilstande:\n- Diabetes")
        XCTAssertEqual(sections.map(\.title), ["Medicines", "Tilstande"])
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

final class TextSizePreferenceTests: XCTestCase {
    func testOnlyExtraLargeRaisesTheMinimum() {
        XCTAssertNil(UserSettings.FontSize.regular.minimumDynamicType)
        XCTAssertNil(UserSettings.FontSize.large.minimumDynamicType)
        XCTAssertEqual(UserSettings.FontSize.extraLarge.minimumDynamicType, .accessibility1)
    }
}
