"""init-project: scaffold the minimal layout the execute-phase skill expects.

Idempotent — never overwrites; reports created vs skipped. handoff_dir is the
project's state-layout directory (greenfield default docs/handoff; projects on
a different handoff convention pass their own — specpipe itself is
layout-agnostic since every subcommand takes explicit paths). The phase-plan
template is read from the plugin's templates/ directory: this file lives at
<plugin>/scripts/specpipe/specpipe/scaffold.py, so the plugin root is
parents[3]. Tests monkeypatch PLUGIN_ROOT.
"""
from __future__ import annotations

from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parents[3]
GITIGNORE_LINE = ".spec-pipeline/"


def init_project(target: Path, handoff_dir: str = "docs/handoff") -> list[str]:
    actions: list[str] = []
    handoff = target / handoff_dir
    audit = handoff / "audit"
    audit.mkdir(parents=True, exist_ok=True)
    actions.append(f"ensured {audit}/")

    plan = handoff / "phase-plan.md"
    if plan.exists():
        actions.append(f"skipped {plan} (exists)")
    else:
        template = PLUGIN_ROOT / "templates" / "phase-plan.md"
        plan.write_text(template.read_text(encoding="utf-8"), encoding="utf-8")
        actions.append(f"created {plan}")

    gitignore = target / ".gitignore"
    existing = gitignore.read_text(encoding="utf-8") if gitignore.exists() else ""
    if GITIGNORE_LINE in existing.split("\n"):
        actions.append(f"skipped {gitignore} ({GITIGNORE_LINE} already present)")
    else:
        with gitignore.open("a", encoding="utf-8") as fh:
            if existing and not existing.endswith("\n"):
                fh.write("\n")
            fh.write(f"{GITIGNORE_LINE}\n")
        actions.append(f"appended {GITIGNORE_LINE} to {gitignore}")
    return actions


def cmd_init_project(args) -> int:
    for action in init_project(Path(args.dir), args.handoff_dir):
        print(action)
    return 0
