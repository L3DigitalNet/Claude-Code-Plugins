# up-docs test suite

## Setup (one-time per worktree)

```bash
cd plugins/up-docs/tests
python3 -m venv .venv
.venv/bin/pip install -e ".[test]"
```

For DeepEval LLM-judge tests (Task 28, optional):

```bash
.venv/bin/pip install -e ".[all]"
```

## Running

Bats (shell-script) suite:

```bash
bash plugins/up-docs/tests/run-bats.sh
```

Pytest (Python validators + verifier):

```bash
cd plugins/up-docs/tests
.venv/bin/python -m pytest -v
```

Integration suite (gated behind `RUN_INTEGRATION=1`, makes real Claude API calls — see `tests/integration/`):

```bash
RUN_INTEGRATION=1 bash plugins/up-docs/tests/run-bats.sh tests/integration/
```

DeepEval LLM-judge (gated behind `RUN_LLMJUDGE=1`, requires `ANTHROPIC_API_KEY`):

```bash
cd plugins/up-docs/tests && \
  RUN_LLMJUDGE=1 ANTHROPIC_API_KEY=sk-ant-... DEEPEVAL_TELEMETRY_OPT_OUT=YES \
  .venv/bin/python -m pytest test_agent_prose.py -v
```

Note: env-var prefix in POSIX shell binds to the next _single_ simple command. Putting the prefix before `cd` would set the variables for `cd` only, not `pytest`. The `cd` must run first, then the prefix-and-pytest command is a single simple command in the shell's view.
