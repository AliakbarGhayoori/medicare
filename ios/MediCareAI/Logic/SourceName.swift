import Foundation

/// A readable publisher name for a citation's source ("mayoclinic.org" → "Mayo Clinic").
enum SourceName {
    private static let known: [String: String] = [
        "mayoclinic.org": "Mayo Clinic",
        "nhs.uk": "NHS",
        "cdc.gov": "CDC",
        "nih.gov": "NIH",
        "nia.nih.gov": "National Institute on Aging",
        "pubmed.ncbi.nlm.nih.gov": "PubMed",
        "medlineplus.gov": "MedlinePlus",
        "fda.gov": "FDA",
        "who.int": "WHO",
        "clevelandclinic.org": "Cleveland Clinic",
        "hopkinsmedicine.org": "Johns Hopkins Medicine",
        "health.harvard.edu": "Harvard Health",
        "webmd.com": "WebMD",
        "healthline.com": "Healthline",
        "medicalnewstoday.com": "Medical News Today",
        "verywellhealth.com": "Verywell Health",
        "everydayhealth.com": "Everyday Health",
        "drugs.com": "Drugs.com",
        "rxlist.com": "RxList",
        "merckmanuals.com": "Merck Manuals",
        "msdmanuals.com": "MSD Manuals",
        "patient.info": "Patient",
        "nice.org.uk": "NICE",
        "diabetes.org.uk": "Diabetes UK",
        "diabetes.org": "American Diabetes Association",
        "heart.org": "American Heart Association",
        "bhf.org.uk": "British Heart Foundation",
        "stroke.org": "American Stroke Association",
        "cancer.org": "American Cancer Society",
        "cancer.gov": "National Cancer Institute",
        "kidney.org": "National Kidney Foundation",
        "arthritis.org": "Arthritis Foundation",
        "alz.org": "Alzheimer's Association",
        "aafp.org": "AAFP",
        "sundhed.dk": "Sundhed.dk",
    ]

    static func display(for source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("."), !trimmed.contains(" ") else { return trimmed }
        var host = trimmed.lowercased()
        if host.hasPrefix("www.") { host.removeFirst(4) }

        var candidate = host
        while candidate.contains(".") {
            if let name = known[candidate] { return name }
            guard let dot = candidate.firstIndex(of: ".") else { break }
            candidate = String(candidate[candidate.index(after: dot)...])
        }
        return host
    }
}
