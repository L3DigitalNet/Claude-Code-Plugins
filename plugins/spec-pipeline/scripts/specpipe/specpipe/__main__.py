"""specpipe CLI — deterministic validators + state ops for spec-pipeline.

Dispatch is lazy (handlers are "module:function" strings) so each subcommand
imports only its own module: a defect in one validator cannot break the rest
of the CLI, and modules can land task-by-task during the build.
"""
from __future__ import annotations

import argparse
import sys
from importlib import import_module


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="specpipe")
    sub = p.add_subparsers(dest="command", required=True)

    v = sub.add_parser("validate", help="structural validators")
    vsub = v.add_subparsers(dest="artifact", required=True)

    vpp = vsub.add_parser("phase-plan", help="phase-plan schema + dependency graph")
    vpp.add_argument("path")
    vpp.add_argument("--json", action="store_true")
    vpp.set_defaults(handler="specpipe.phaseplan:cmd_validate")

    vs = vsub.add_parser("spec", help="spec structure (core + master/phase delta)")
    vs.add_argument("path")
    vs.add_argument("--kind", choices=["master", "phase"], required=True)
    vs.add_argument("--master", help="master spec path (required for --kind phase)")
    vs.add_argument("--json", action="store_true")
    vs.set_defaults(handler="specpipe.specdoc:cmd_validate_spec")

    vp = vsub.add_parser("plan", help="implementation-plan structure + TDD order")
    vp.add_argument("path")
    vp.add_argument("--json", action="store_true")
    vp.set_defaults(handler="specpipe.plandoc:cmd_validate_plan")

    np = sub.add_parser("next-phase", help="resolve first pending phase with deps complete")
    np.add_argument("path")
    np.add_argument("--json", action="store_true")
    np.set_defaults(handler="specpipe.phaseplan:cmd_next_phase")

    ss = sub.add_parser("set-status", help="legal status transition, atomic rewrite")
    ss.add_argument("path")
    ss.add_argument("--id", type=int, required=True)
    ss.add_argument("--to", required=True)
    ss.set_defaults(handler="specpipe.phaseplan:cmd_set_status")

    st = sub.add_parser("status", help="render phase table + round counters")
    st.add_argument("path")
    st.add_argument("--state", help="explicit state.json path (default: upward "
                                    "search from the phase-plan for .spec-pipeline/state.json)")
    st.add_argument("--json", action="store_true")
    st.set_defaults(handler="specpipe.phaseplan:cmd_status")

    rr = sub.add_parser("record-red", help="run test cmd, assert genuine failure, append evidence")
    rr.add_argument("--cmd", required=True)
    rr.add_argument("--task", required=True)
    rr.add_argument("--audit", required=True)
    rr.add_argument("--framework", choices=["pytest", "generic"], default="pytest",
                    help="pytest: reject collection/import errors as non-RED; "
                         "generic: bats/Jest/other runners (pair with "
                         "--expect-failure-regex to keep fails-for-the-right-reason)")
    rr.add_argument("--expect-failure-regex",
                    help="REQUIRED with --framework generic: output must match this "
                         "regex for RED to count (the expected failing assertion / "
                         "missing symbol); enforced in the handler")
    rr.add_argument("--timeout", type=float, default=600.0)
    rr.set_defaults(handler="specpipe.evidence:cmd_record_red")

    rg = sub.add_parser("record-green", help="run test cmd, assert genuine pass, append evidence")
    rg.add_argument("--cmd", required=True)
    rg.add_argument("--task", required=True)
    rg.add_argument("--audit", required=True)
    rg.add_argument("--framework", choices=["pytest", "generic"], default="pytest",
                    help="pytest: require a positive 'N passed' marker (exit 0 "
                         "alone proves nothing); generic: bats/Jest/other runners "
                         "(pair with --expect-success-regex)")
    rg.add_argument("--expect-success-regex",
                    help="REQUIRED with --framework generic: output must match this "
                         "regex for GREEN to count (the runner's success signature); "
                         "enforced in the handler")
    rg.add_argument("--timeout", type=float, default=600.0)
    rg.set_defaults(handler="specpipe.evidence:cmd_record_green")

    ro = sub.add_parser("rounds", help="review-round counters vs caps (3/3/5)")
    ro.add_argument("state")
    ro.add_argument("--gate", choices=["spec", "plan", "final"])
    ro.add_argument("--increment", action="store_true")
    ro.add_argument("--reset", action="store_true")
    ro.set_defaults(handler="specpipe.rounds:cmd_rounds")

    ip = sub.add_parser("init-project", help="scaffold minimal handoff layout (idempotent)")
    ip.add_argument("--dir", default=".")
    ip.add_argument("--handoff-dir", default="docs/handoff",
                    help="state-layout directory relative to --dir (projects not "
                         "on the docs/handoff convention pass their own)")
    ip.set_defaults(handler="specpipe.scaffold:cmd_init_project")
    return p


def main(argv: list[str] | None = None) -> int:
    if sys.version_info < (3, 11):
        # `uv run --no-project python` takes whatever interpreter uv discovers;
        # fail crisply instead of with an arbitrary traceback mid-gate.
        version = ".".join(str(n) for n in sys.version_info[:3])
        print(f"ERROR: specpipe requires Python >= 3.11 (running {version})")
        return 2
    args = build_parser().parse_args(argv)
    mod_name, fn_name = args.handler.split(":")
    handler = getattr(import_module(mod_name), fn_name)
    return handler(args)


if __name__ == "__main__":
    sys.exit(main())
