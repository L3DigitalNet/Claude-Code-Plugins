from specpipe import grammar

DOC = """\
# Title

intro

## Alpha

alpha body

```bash
## not a heading — inside a fence
```

still alpha

## Beta section

beta body

### Beta child

child body
"""


def test_split_sections_fence_aware():
    sections = grammar.split_sections(DOC)
    titles = [t for t, _, _ in sections]
    assert titles == ["Alpha", "Beta section"]
    alpha = sections[0]
    assert "## not a heading — inside a fence" in alpha[2]
    assert "still alpha" in alpha[2]


def test_split_sections_child_headings_stay_in_body():
    sections = grammar.split_sections(DOC)
    beta = sections[1]
    assert "### Beta child" in beta[2] and "child body" in beta[2]


def test_find_section_startswith_case_insensitive():
    sections = grammar.split_sections(DOC)
    assert grammar.find_section(sections, "beta")[0] == "Beta section"
    assert grammar.find_section(sections, "Gamma") is None


def test_strip_fences_removes_fenced_lines():
    lines = dict(grammar.strip_fences(DOC))
    assert all("not a heading" not in line for line in lines.values())
    assert any("beta body" in line for line in lines.values())


def test_placeholder_re():
    assert grammar.PLACEHOLDER_RE.search("this is TBD")
    assert grammar.PLACEHOLDER_RE.search("weird ??? marker")
    assert not grammar.PLACEHOLDER_RE.search("TODOS are fine as a word")


def test_transitions_and_caps():
    assert ("pending", "in_progress") in grammar.LEGAL_TRANSITIONS
    assert ("in_progress", "pending") in grammar.LEGAL_TRANSITIONS  # recovery
    assert ("pending", "complete") not in grammar.LEGAL_TRANSITIONS
    assert grammar.ROUND_CAPS == {"spec": 3, "plan": 3, "final": 5}
