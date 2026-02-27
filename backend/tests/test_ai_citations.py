from __future__ import annotations

from src.ai.citations import extract_citations_from_response, validate_citations


def test_extract_citations_from_sources_block() -> None:
    response_text = """This may be related to dehydration [1].

Sources:
[1] Mayo Clinic - \"Dizziness\" (https://www.mayoclinic.org/symptoms/dizziness/)
[2] NIH - \"Dehydration\" (https://www.nih.gov/example)
"""

    clean_text, citations = extract_citations_from_response(response_text)
    citations = validate_citations(clean_text, citations)

    assert "Sources:" not in clean_text
    assert len(citations) == 1
    assert citations[0].number == 1
    assert citations[0].source.startswith("Mayo")
    assert citations[0].url.startswith("https://")


def test_ignore_invalid_unreferenced_citation() -> None:
    response_text = """General guidance only.

Sources:
[2] Example - \"Bad\" (invalid-url)
"""

    clean_text, citations = extract_citations_from_response(response_text)
    validated = validate_citations(clean_text, citations)

    assert validated == []
