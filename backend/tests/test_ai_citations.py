from __future__ import annotations

from src.ai.citations import finalize_citations
from src.ai.sources import SourceRegistry

# --- Grounded citations: numbers come from the server-side source registry ---


def _result(i: int, content: str | None = None) -> dict:
    return {
        "title": f"Title {i}",
        "url": f"https://example{i}.org/page",
        "source": f"example{i}.org",
        "content": content if content is not None else f"Content {i}",
    }


def _registry(count: int) -> SourceRegistry:
    registry = SourceRegistry()
    registry.register([_result(i) for i in range(1, count + 1)])
    return registry


def test_registry_numbers_results_and_dedupes_urls() -> None:
    registry = SourceRegistry()
    first = registry.register([_result(1), _result(2)])
    second = registry.register([_result(2), _result(3)])

    assert [item["n"] for item in first] == [1, 2]
    assert [item["n"] for item in second] == [2, 3]
    assert len(registry) == 3
    assert set(first[0]) == {"n", "title", "source", "url", "content"}
    source = registry.get(3)
    assert source is not None and source.url == "https://example3.org/page"


def test_registry_snippet_is_capped_for_display() -> None:
    registry = SourceRegistry()
    model_facing = registry.register([_result(1, content="x" * 1000)])

    source = registry.get(1)
    assert source is not None and len(source.snippet) <= 300
    assert len(model_facing[0]["content"]) == 1000


def test_cited_numbers_map_to_registered_results_and_renumber() -> None:
    text, citations = finalize_citations("A [2]. B [3]. C [2].", _registry(3))

    assert text == "A [1]. B [2]. C [1]."
    assert [(c.number, c.url) for c in citations] == [
        (1, "https://example2.org/page"),
        (2, "https://example3.org/page"),
    ]
    assert (citations[0].title, citations[0].source, citations[0].snippet) == (
        "Title 2",
        "example2.org",
        "Content 2",
    )


def test_marker_for_unknown_source_is_removed() -> None:
    text, citations = finalize_citations("Claim [9].", _registry(2))

    assert text == "Claim."
    assert citations == []


def test_danish_sources_block_from_production_is_stripped() -> None:
    body = "Agomelatin giver sjældent seponeringssymptomer [2]. Søg læge ved åndenød [1]."
    text = (
        body + "\n\nKilder:\n"
        "[1] NHS SPS – Agomelatine to other antidepressants — https://sps.nhs.uk/a\n"
        "[2] PubMed – Absence of discontinuation symptoms — "
        "https://pubmed.ncbi.nlm.nih.gov/15289700/"
    )

    clean, citations = finalize_citations(text, _registry(2))

    assert clean == "Agomelatin giver sjældent seponeringssymptomer [1]. Søg læge ved åndenød [2]."
    assert [c.url for c in citations] == [
        "https://example2.org/page",
        "https://example1.org/page",
    ]


def test_markdown_bullet_sources_block_is_stripped() -> None:
    text = (
        "Rest and fluids help [1].\n\n**Sources**\n"
        "- [Mayo Clinic: Dizziness](https://www.mayoclinic.org/x)\n"
        "- https://www.nhs.uk/y\n"
    )

    clean, citations = finalize_citations(text, _registry(1))

    assert clean == "Rest and fluids help [1]."
    assert len(citations) == 1


def test_marker_variants_resolve() -> None:
    clean, citations = finalize_citations("x [^2] y 【1】 z [1][2] w [1, 3]", _registry(3))

    assert clean == "x [1] y [2] z [2, 1] w [2, 3]"
    assert len(citations) == 3


def test_range_marker_expands() -> None:
    clean, citations = finalize_citations("See [1-3].", _registry(3))

    assert clean == "See [1, 2, 3]."
    assert len(citations) == 3


def test_text_without_markers_has_no_citations() -> None:
    clean, citations = finalize_citations("Drink water and rest.", _registry(2))

    assert clean == "Drink water and rest."
    assert citations == []


def test_prose_line_with_link_is_kept() -> None:
    text = (
        "You're welcome! For more on staying hydrated, see https://www.nhs.uk/live-well/ any time."
    )

    clean, citations = finalize_citations(text, _registry(1))

    assert clean == text
    assert citations == []


def test_trailing_crisis_lines_with_link_are_kept() -> None:
    text = (
        "Du er ikke alene [1].\n\n"
        "**Hvis du har tanker om at skade dig selv:**\n"
        "- Ring 112 ved akut fare\n"
        "- Livslinien: 70 201 201\n"
        "- Find en hjælpelinje: https://findahelpline.com"
    )

    clean, citations = finalize_citations(text, _registry(1))

    assert clean == text
    assert len(citations) == 1


def test_numbered_reference_list_without_heading_is_stripped() -> None:
    text = (
        "Rest helps [1].\n\n"
        "[1] Mayo Clinic — https://www.mayoclinic.org/x\n"
        "[2] NHS — https://www.nhs.uk/y"
    )

    clean, citations = finalize_citations(text, _registry(2))

    assert clean == "Rest helps [1]."
    assert len(citations) == 1


def test_answer_is_never_stripped_to_nothing() -> None:
    text = "Sources:\n- https://www.nhs.uk/y"

    clean, _ = finalize_citations(text, _registry(1))

    assert clean == text
