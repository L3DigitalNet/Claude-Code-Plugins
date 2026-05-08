"""Validate up-docs sub-agent output against canonical schemas.

Usage:
    python3 validate_output.py <agent-name> < agent_output.json

Agent names accepted:
    up-docs-propagate-repo
    up-docs-propagate-wiki
    up-docs-propagate-notion
    up-docs-audit-drift

Exit:
    0 = output is valid against the schema and all invariants
    1 = schema or invariant violation (error written to stderr)
    2 = unknown agent name or malformed JSON input

Design notes:
    * `LayeredReport` is a Pydantic v2 discriminated union over the `layer`
      field. A wrong-layer value (e.g. wiki agent emitting `"layer":"repo"`)
      surfaces as `union_tag_invalid` naming both the bad tag and the
      expected literals — diagnosing CR-008's wrong-layer bug structurally.
    * `Finding.evidence` is a structured object `{command,
      expected_output_signature, source_tool_use_id}`, not a free-form
      string. A fabricated evidence string ("ssh host returned 1.0.0")
      can't satisfy the schema. The verifier (verify_evidence_grounded.py)
      enforces that `expected_output_signature` actually appears in
      `tool_response.output`, not in `tool_input` (CR-003).
"""
from __future__ import annotations

import json
import re
import sys
from typing import Annotated, Any, Callable, Literal, Union

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    TypeAdapter,
    ValidationError,
    field_validator,
)

IPV4_RE = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")


# -----------------------------------------------------------------------------
# Propagator output schemas (discriminated union over `layer`)
# -----------------------------------------------------------------------------

class Row(BaseModel):
    model_config = ConfigDict(extra="forbid")
    n: int
    target: str
    action: Literal["Created", "Updated", "No change needed", "FAILED"]
    summary: str


class Totals(BaseModel):
    model_config = ConfigDict(extra="forbid")
    updated: int
    created: int
    unchanged: int
    failed: int


class _PropagatorBase(BaseModel):
    """Shared fields. Each subclass adds its own `layer: Literal[...]`."""
    model_config = ConfigDict(extra="forbid")
    rows: list[Row]
    totals: Totals

    @field_validator("totals")
    @classmethod
    def totals_match_rows(cls, v: Totals, info) -> Totals:
        rows: list[Row] = info.data.get("rows", [])
        counted = {"updated": 0, "created": 0, "unchanged": 0, "failed": 0}
        for r in rows:
            if r.action == "Updated":
                counted["updated"] += 1
            elif r.action == "Created":
                counted["created"] += 1
            elif r.action == "No change needed":
                counted["unchanged"] += 1
            elif r.action == "FAILED":
                counted["failed"] += 1
        if (v.updated, v.created, v.unchanged, v.failed) != (
            counted["updated"], counted["created"], counted["unchanged"], counted["failed"]
        ):
            raise ValueError(
                f"totals do not match row actions: declared={v.model_dump()}, counted={counted}"
            )
        return v


class RepoReport(_PropagatorBase):
    layer: Literal["repo"] = "repo"


class WikiReport(_PropagatorBase):
    layer: Literal["wiki"] = "wiki"


class NotionReport(_PropagatorBase):
    layer: Literal["notion"] = "notion"

    @field_validator("rows")
    @classmethod
    def no_ipv4_in_summary(cls, v: list[Row]) -> list[Row]:
        for row in v:
            if IPV4_RE.search(row.summary):
                raise ValueError(
                    f"IPv4 leaked into Notion summary for row {row.n}: {row.summary!r}"
                )
        return v


# Discriminated union — Pydantic dispatches on the `layer` field.
PropagatorReport = Annotated[
    Union[RepoReport, WikiReport, NotionReport],
    Field(discriminator="layer"),
]


# -----------------------------------------------------------------------------
# Auditor output schema (structured evidence per CR-003)
# -----------------------------------------------------------------------------

class Evidence(BaseModel):
    """Structured evidence per CR-003. Free-form strings are NOT allowed.

    `command`: the exact tool_input.command string the auditor expected to
        run. Verifier matches this against transcript tool_input commands.
    `expected_output_signature`: a distinctive substring the auditor expects
        to find in tool_response.output. Verifier requires this to appear in
        the OUTPUT (not the union), so an auditor that ran a command but
        misread the output cannot evade detection.
    `source_tool_use_id`: optional. If the auditor recorded which tool_use_id
        produced the evidence, the verifier can scope the search to that
        single call rather than the full transcript.
    """
    model_config = ConfigDict(extra="forbid")
    command: str
    expected_output_signature: str
    source_tool_use_id: str | None = None


class Finding(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: int
    layer: Literal["repo", "wiki", "notion"]
    page: str
    page_id: str | None
    stale_line: str
    should_say: str
    confidence: Literal["high", "medium", "low", "unverifiable"]
    destructive_fix: bool
    evidence: Evidence | None  # None only when confidence='unverifiable' and command failed

    @field_validator("evidence")
    @classmethod
    def evidence_required_unless_unverifiable(cls, v, info):
        confidence = info.data.get("confidence")
        if confidence == "unverifiable":
            return v  # None or Evidence with command failed-style signature both ok
        if v is None:
            raise ValueError(
                f"Finding with confidence={confidence!r} must have a non-null evidence object"
            )
        return v


class Escalation(BaseModel):
    model_config = ConfigDict(extra="forbid")
    triggered: bool
    reasons: list[str]


class StatsByLayer(BaseModel):
    model_config = ConfigDict(extra="forbid")
    repo: int
    wiki: int
    notion: int


class Stats(BaseModel):
    model_config = ConfigDict(extra="forbid")
    total_findings: int
    by_layer: StatsByLayer
    high_confidence: int
    unverifiable: int
    destructive_fixes_required: int


class AuditorReport(BaseModel):
    model_config = ConfigDict(extra="forbid")
    findings: list[Finding]
    escalation: Escalation
    stats: Stats

    @field_validator("stats")
    @classmethod
    def stats_consistency(cls, v: Stats, info) -> Stats:
        findings: list[Finding] = info.data.get("findings", [])
        if v.total_findings != len(findings):
            raise ValueError(
                f"stats.total_findings ({v.total_findings}) != len(findings) ({len(findings)})"
            )
        return v


# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

PROPAGATOR_ADAPTER: TypeAdapter[PropagatorReport] = TypeAdapter(PropagatorReport)


def validate_propagator(payload: dict) -> _PropagatorBase:
    return PROPAGATOR_ADAPTER.validate_python(payload)


def validate_auditor(payload: dict) -> AuditorReport:
    return AuditorReport.model_validate(payload)


# Map agent name → callable that validates and returns a typed object
VALIDATORS: dict[str, Callable[[dict], Any]] = {
    "up-docs-propagate-repo": validate_propagator,
    "up-docs-propagate-wiki": validate_propagator,
    "up-docs-propagate-notion": validate_propagator,
    "up-docs-audit-drift": validate_auditor,
}


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_output.py <agent-name> < output.json", file=sys.stderr)
        return 2
    agent = sys.argv[1]
    fn = VALIDATORS.get(agent)
    if fn is None:
        print(f"Unknown agent: {agent}", file=sys.stderr)
        return 2
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Malformed JSON input: {e}", file=sys.stderr)
        return 2
    try:
        fn(payload)
    except ValidationError as e:
        print(f"INVALID ({agent}): {e}", file=sys.stderr)
        return 1
    print(f"VALID ({agent})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
