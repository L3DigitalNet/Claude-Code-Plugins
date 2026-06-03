from _frontmatter import extract_frontmatter


def test_extracts_leading_block():
    text = "---\nid: x\ntags:\n  - a\n---\n\n# Body\n"
    assert extract_frontmatter(text) == {"id": "x", "tags": ["a"]}


def test_absent_block_returns_none():
    assert extract_frontmatter("# No frontmatter here\n") is None


def test_block_not_at_top_is_not_frontmatter():
    text = "Intro paragraph\n\n---\nid: x\n---\n"
    assert extract_frontmatter(text) is None


def test_non_mapping_returns_none():
    # A YAML list at the top is not a frontmatter mapping.
    assert extract_frontmatter("---\n- a\n- b\n---\n") is None


def test_unquoted_dates_coerced_to_iso_strings():
    # YAML parses unquoted dates as datetime.date; the string-typed schema
    # needs ISO strings. (CR-003)
    fm = extract_frontmatter("---\ncreated: 2026-06-03\nupdated: 2026-06-03\n---\n")
    assert fm == {"created": "2026-06-03", "updated": "2026-06-03"}
    assert isinstance(fm["created"], str)
