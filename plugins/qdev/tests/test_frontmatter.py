import pytest
import yaml

from _frontmatter import extract_frontmatter


def test_crlf_line_endings_are_handled():
    text = "---\r\nid: x\r\ntags:\r\n  - a\r\n---\r\n\r\n# Body\r\n"
    assert extract_frontmatter(text) == {"id": "x", "tags": ["a"]}


def test_empty_block_returns_none():
    # `---\n\n---` has no mapping content; safe_load -> None -> not a mapping.
    assert extract_frontmatter("---\n\n---\n") is None


def test_malformed_yaml_raises():
    # Documented contract: malformed YAML raises (validators catch it per-file).
    with pytest.raises(yaml.YAMLError):
        extract_frontmatter("---\nid: [unbalanced\n---\n")


def test_datetime_timestamp_coerced_to_iso_date():
    # A full YAML timestamp parses as datetime.datetime; coerced to an ISO date.
    fm = extract_frontmatter("---\ncreated: 2026-06-03 10:30:00\n---\n")
    assert fm == {"created": "2026-06-03"}
    assert isinstance(fm["created"], str)


def test_dates_coerced_recursively_in_lists_and_dicts():
    text = "---\nrelated:\n  - 2026-06-03\nmeta:\n  d: 2026-06-03\n---\n"
    assert extract_frontmatter(text) == {
        "related": ["2026-06-03"], "meta": {"d": "2026-06-03"}}


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
