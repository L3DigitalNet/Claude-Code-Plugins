import json as _json
import stat
import subprocess
import time
from pathlib import Path

import pytest
from sanitize_query import sanitize

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "sanitize_query.py"


def _egress(r):
    """Everything that could leave the machine: safe_query + the labels."""
    return r["safe_query"] + " | " + " | ".join(r["dropped_fields"])


# Sensitive families incl. current variants: redacted, flag, no leak.
# All values are fake / non-live, shape-valid so they match the production regexes.
SECRET_CASES = [
    ("openai", "sk-abcdef0123456789ABCDEFGHIJ", "secret:openai-key"),
    ("openai_project", "sk-proj-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKL0123456789", "secret:openai-key"),
    ("github", "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", "secret:github-token"),
    ("github_oauth", "gho_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", "secret:github-token"),
    ("github_user", "ghu_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", "secret:github-token"),
    ("github_refresh", "ghr_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", "secret:github-token"),
    (
        "github_stateless",
        "ghs_123456_eyJhbGciOiJIUzI1.eyJzdWIiOiIxMjM0.SflKxwRJSMeKKF2QT",
        "secret:github-token",
    ),
    ("github_pat", "github_pat_11ABCDE0000aBcDeFgHiJ123456", "secret:github-pat"),
    ("aws_akia", "AKIAIOSFODNN7EXAMPLE", "secret:aws-access-key"),
    ("aws_asia", "ASIAIOSFODNN7EXAMPLE", "secret:aws-access-key"),
    ("google", "AIza" + "B" * 35, "secret:google-key"),
    ("slack_xoxb", "xoxb-123456789012-ABCDEFabcdef", "secret:slack-token"),
    ("slack_xoxa", "xoxa-123456789012-ABCDEFabcdef", "secret:slack-token"),
    ("slack_xoxp", "xoxp-123456789012-ABCDEFabcdef", "secret:slack-token"),
    ("slack_xoxr", "xoxr-123456789012-ABCDEFabcdef", "secret:slack-token"),
    ("slack_xoxs", "xoxs-123456789012-ABCDEFabcdef", "secret:slack-token"),
    ("slack_xapp", "xapp-1-A012345678-ABCDEFGHIJ", "secret:slack-token"),
    ("slack_xwfp", "xwfp-ABCDEF0123456789abcdef", "secret:slack-token"),
    ("jwt", "eyJhbGciOiJIUzI1.eyJzdWIiOiIxMjM0.SflKxwRJSMeKKF2QT4", "secret:jwt"),
    ("bearer", "Bearer s3cr3t.tok3n.v4lue99", "secret:bearer"),
    ("assignment", "password=hunter2swordfish", "secret:assignment"),
    ("token_assignment", "token=tokensecretswordfish", "secret:assignment"),
    ("secret_assignment", "secret=secretvalueswordfish", "secret:assignment"),
    ("api_key_assignment", "api-key=apikeyvalueswordfish", "secret:assignment"),
    ("signed_sig", "https://x.example/o?X-Amz-Signature=SIGVALUEsecret123", "secret:signed-url"),
    ("signed_cred", "https://x.example/o?X-Amz-Credential=CREDSECRETvalue123", "secret:signed-url"),
    ("signed_token", "https://x.example/o?X-Amz-Security-Token=TOKENSECRETvalue123", "secret:signed-url"),
    ("customer_id", "customer_id=CUST99887766", "customer:identifier"),
    ("customer_id_space", "customer id=CUST99887766", "customer:identifier"),
    ("account_number_space", "account number: 123456789", "customer:identifier"),
]


@pytest.mark.parametrize("name,secret,label", SECRET_CASES, ids=[c[0] for c in SECRET_CASES])
def test_sensitive_redacted_flags_and_no_leak(name, secret, label):
    raw = secret.split("=")[-1].split()[-1].split("/")[-1]
    r = sanitize(f"debugging this failure: {secret} please help")
    assert r["requires_human_approval"] is True
    assert raw not in _egress(r)
    assert label in r["dropped_fields"]


def test_assignment_with_spaced_value_redacts_whole_value():
    # Regression: the assignment value capture must not stop at the first
    # whitespace token (a passphrase with spaces would otherwise leak its tail).
    r = sanitize("password: correct horse battery staple")
    assert r["requires_human_approval"] is True
    assert "secret:assignment" in r["dropped_fields"]
    assert "horse" not in r["safe_query"]
    assert "battery staple" not in r["safe_query"]


def test_pem_block_redacted_and_flags():
    pem = "-----BEGIN PRIVATE KEY-----\nMIIBVwIBADANBgSECRET\n-----END PRIVATE KEY-----"
    r = sanitize(f"key load error {pem}")
    assert r["requires_human_approval"] is True
    assert "MIIBVwIBADANBgSECRET" not in _egress(r)
    assert "secret:pem" in r["dropped_fields"]


IDENTIFIER_CASES = [
    ("tailscale", "100.90.121.89", "host:tailscale-ip"),
    ("home_path", "/home/chris/projects/app/main.py", "path:home-dir"),
    ("email", "chris@example.com", "pii:email"),
    ("internal", "openbao.tailnet", "host:internal"),
    ("internal_multi_label", "db.prod.internal", "host:internal"),
]


@pytest.mark.parametrize(
    "name,value,label", IDENTIFIER_CASES, ids=[c[0] for c in IDENTIFIER_CASES]
)
def test_identifier_stripped_no_flag(name, value, label):
    r = sanitize(f"connect to {value} then retry")
    assert r["requires_human_approval"] is False
    assert value not in _egress(r)
    assert label in r["dropped_fields"]
    if label == "host:internal":
        assert r["safe_query"] == "connect to <host> then retry"


def test_traceback_collapses_to_exception_summary():
    tb = (
        'Traceback (most recent call last):\n'
        '  File "/home/chris/x.py", line 10, in <module>\n'
        "    result = calculate_private(foo, bar)\n"
        "ValueError: bad thing"
    )
    r = sanitize(tb)
    assert "ValueError: bad thing" in r["safe_query"]
    assert "calculate_private" not in r["safe_query"]
    assert 'File "' not in r["safe_query"]
    assert "trace:frames" in r["dropped_fields"]


def test_exception_group_traceback_collapses_frames():
    tb = (
        "+ Exception Group Traceback (most recent call last):\n"
        '|   File "/home/chris/app.py", line 1, in <module>\n'
        "|     main()\n"
        "| ExceptionGroup: group failure (1 sub-exception)\n"
        "+-+---------------- 1 ----------------\n"
        "  | Traceback (most recent call last):\n"
        '  |   File "/home/chris/app.py", line 2, in task\n'
        "  |     do()\n"
        "  | ValueError: bad thing\n"
        "  +------------------------------------"
    )
    r = sanitize(tb)
    assert "ExceptionGroup: group failure" in r["safe_query"]
    assert "ValueError: bad thing" in r["safe_query"]
    assert 'File "' not in r["safe_query"]
    assert "/home/chris" not in _egress(r)
    assert "trace:frames" in r["dropped_fields"]


def test_dense_code_excerpt_removed_and_flags():
    code = "\n".join(f"x{i} = foo(bar[{i}]);" for i in range(8))
    r = sanitize(f"why is this slow:\n{code}")
    assert r["requires_human_approval"] is True
    assert "proprietary:code-excerpt" in r["dropped_fields"]
    assert "foo(bar" not in r["safe_query"]


def test_dense_code_excerpt_with_secret_reports_both_labels():
    secret = "sk-abcdef0123456789ABCDEFGHIJ"
    code = "\n".join(f'const key{i} = "{secret}";' for i in range(6))
    r = sanitize(f"why is this failing:\n{code}")
    assert r["requires_human_approval"] is True
    assert secret not in _egress(r)
    assert "proprietary:code-excerpt" in r["dropped_fields"]
    assert "secret:openai-key" in r["dropped_fields"]


def test_python_keyword_excerpt_removed_and_flags():
    code = "\n".join(
        [
            "import os",
            "from x import y",
            "def run():",
            "return z",
            "for i in items:",
            "while True:",
        ]
    )
    r = sanitize(f"help with this:\n{code}")
    assert r["requires_human_approval"] is True
    assert "proprietary:code-excerpt" in r["dropped_fields"]
    assert "def run" not in r["safe_query"]


def test_yaml_config_excerpt_removed_and_flags():
    cfg = "\n".join(
        ["name: app", "host: db", "port: 5432", "user: admin", "pool: ten", "mode: prod"]
    )
    r = sanitize(f"why won't this config load:\n{cfg}")
    assert r["requires_human_approval"] is True
    assert "proprietary:code-excerpt" in r["dropped_fields"]


def test_clean_query_all_providers_allowed():
    r = sanitize("current stable version of ruff")
    assert r["requires_human_approval"] is False
    assert r["provider_allowed"] == {
        "brave": True,
        "context7": True,
        "tavily": True,
        "serper": True,
    }
    assert r["dropped_fields"] == []


def test_short_prose_not_flagged_as_code():
    r = sanitize("what is the latest version of the requests library and is it maintained")
    assert r["requires_human_approval"] is False


def test_multiline_issue_prose_not_flagged_as_code():
    prose = "\n".join(
        [
            "Context: I am comparing two current library versions.",
            "Expected: The docs should identify the stable release.",
            "Observed: The changelog and README disagree.",
            "Notes: This is a prose troubleshooting summary.",
            "Question: Which source should I trust today?",
            "Result: Please answer with a short recommendation.",
        ]
    )
    r = sanitize(prose)
    assert r["requires_human_approval"] is False
    assert "proprietary:code-excerpt" not in r["dropped_fields"]


def test_lowercase_issue_fields_not_flagged_as_code():
    prose = "\n".join(
        [
            "title: login fails",
            "expected: login succeeds",
            "actual: login fails",
            "steps: open app",
            "env: production",
            "impact: users blocked",
        ]
    )
    r = sanitize(prose)
    assert r["requires_human_approval"] is False
    assert "proprietary:code-excerpt" not in r["dropped_fields"]


def test_research_handoff_fields_not_flagged_as_code():
    handoff = "\n".join(
        [
            "library: requests",
            "version: latest",
            "source: docs",
            "topic: retries",
            "provider: context7",
            "status: current",
        ]
    )
    r = sanitize(handoff)
    assert r["requires_human_approval"] is False
    assert "proprietary:code-excerpt" not in r["dropped_fields"]


def test_keyword_starting_research_prose_not_flagged_as_code():
    prose = "\n".join(
        [
            "if the current version changed, verify it from docs",
            "for this library, compare the release notes",
            "with the latest guidance, summarize the answer",
            "return a short recommendation with caveats",
            "from official docs, cite the source",
            "try one more source if the first is stale",
        ]
    )
    r = sanitize(prose)
    assert r["requires_human_approval"] is False
    assert "proprietary:code-excerpt" not in r["dropped_fields"]


def test_flagged_query_no_provider_allowed():
    r = sanitize("sk-abcdef0123456789ABCDEFGHIJ")
    assert r["requires_human_approval"] is True
    assert all(v is False for v in r["provider_allowed"].values())


def test_dropped_fields_are_labels_only():
    r = sanitize("/home/chris/a /home/chris/b chris@x.com chris@y.com")
    for d in r["dropped_fields"]:
        assert ":" in d and "/" not in d and "@" not in d
    assert r["dropped_fields"].count("path:home-dir") == 1


# --- contract invariants ---

def test_empty_input_is_clean_no_approval():
    r = sanitize("")
    assert r == {
        "safe_query": "",
        "dropped_fields": [],
        "provider_allowed": {"brave": True, "context7": True, "tavily": True, "serper": True},
        "requires_human_approval": False,
    }


def test_whitespace_only_input_is_clean():
    r = sanitize("   \n\t  ")
    assert r["safe_query"] == ""
    assert r["dropped_fields"] == []
    assert r["requires_human_approval"] is False


def test_sanitize_is_idempotent_on_its_own_safe_query():
    # Re-sanitizing the output must be a fixed point: the [REDACTED]/<path>
    # markers must not themselves match any pattern and re-flag.
    once = sanitize("debug sk-abcdef0123456789ABCDEFGHIJ at /home/chris/x.py")
    twice = sanitize(once["safe_query"])
    assert twice["safe_query"] == once["safe_query"]
    assert twice["requires_human_approval"] is False
    assert twice["dropped_fields"] == []


def test_two_secrets_same_family_both_redacted():
    a, b = "sk-AAAAAAAAAAAAAAAAAAAA", "sk-BBBBBBBBBBBBBBBBBBBB"
    r = sanitize(f"keys {a} and {b}")
    assert a not in _egress(r)
    assert b not in _egress(r)
    assert r["dropped_fields"].count("secret:openai-key") == 1  # one label, both redacted


def test_multiple_distinct_families_all_redacted_and_labeled():
    aws = "AKIAIOSFODNN7EXAMPLE"
    gh = "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    r = sanitize(f"creds {aws} and {gh} leaked")
    assert aws not in _egress(r)
    assert gh not in _egress(r)
    assert "secret:aws-access-key" in r["dropped_fields"]
    assert "secret:github-token" in r["dropped_fields"]
    assert r["requires_human_approval"] is True


def test_secret_hidden_in_traceback_frame_does_not_leak():
    # A secret on a dropped frame line is removed by traceback collapse. The
    # binding contract is no-leak; it is collapsed as a frame (not flagged as a
    # secret), which is acceptable because it never reaches safe_query.
    tb = (
        "Traceback (most recent call last):\n"
        '  File "/x.py", line 2, in f\n'
        '    auth = "Bearer sk-abcdef0123456789ABCDEFGHIJ"\n'
        "ValueError: boom"
    )
    r = sanitize(tb)
    assert "sk-abcdef0123456789ABCDEFGHIJ" not in _egress(r)
    assert r["safe_query"] == "ValueError: boom"


def test_identifier_only_keeps_all_providers_allowed():
    r = sanitize("ping /home/chris/app and chris@example.com")
    assert r["requires_human_approval"] is False
    assert all(r["provider_allowed"].values())


def test_no_redos_on_pathological_input():
    # Guards against a future regex edit reintroducing catastrophic backtracking.
    # Probed baseline is well under 0.2s; the bound is deliberately generous.
    payloads = [
        "-----BEGIN PRIVATE KEY-----" + "A" * 200_000,   # unterminated PEM
        "Bearer " + "a " * 100_000,                       # many bearer near-matches
        "x = y;" * 100_000,                               # dense single line
    ]
    for payload in payloads:
        start = time.perf_counter()
        sanitize(payload)
        assert time.perf_counter() - start < 2.0


def test_cli_stdin_transport_redacts_no_leak(tmp_path):
    secret = "sk-abcdef0123456789ABCDEFGHIJ"
    payload = tmp_path / "payload.txt"
    payload.write_text(f"why does {secret} fail", encoding="utf-8")
    payload.chmod(0o600)
    assert stat.S_IMODE(payload.stat().st_mode) == 0o600

    with payload.open("rb") as fh:
        proc = subprocess.run(
            ["uv", "run", str(SCRIPT)],
            stdin=fh,
            capture_output=True,
            text=True,
            check=True,
        )

    result = _json.loads(proc.stdout)
    assert secret not in proc.stdout
    assert result["requires_human_approval"] is True
