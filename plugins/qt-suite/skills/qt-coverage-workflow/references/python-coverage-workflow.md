# Python Coverage Workflow Reference

## Installation

```bash
pip install coverage pytest-cov
```

## Running Coverage

### Via pytest-cov (Recommended)

```bash
# Basic — measures coverage of myapp package
pytest --cov=myapp tests/

# With missing line numbers in terminal report
pytest --cov=myapp --cov-report=term-missing tests/

# HTML report (browsable)
pytest --cov=myapp --cov-report=html:htmlcov tests/

# XML report (for CI/SonarQube parsing)
pytest --cov=myapp --cov-report=xml:coverage.xml tests/

# Fail if coverage drops below threshold
pytest --cov=myapp --cov-fail-under=80 tests/

# Multiple output formats at once
pytest --cov=myapp \
       --cov-report=term-missing \
       --cov-report=html:htmlcov \
       --cov-report=xml:coverage.xml \
       tests/
```

### Via coverage CLI

```bash
coverage run -m pytest tests/
coverage report --show-missing
coverage html -d htmlcov
coverage xml -o coverage.xml
coverage json -o coverage.json  # machine-readable
```

## Configuration

### pyproject.toml (Recommended)

```toml
[tool.coverage.run]
source = ["myapp"]
omit = [
    "tests/*",
    "*/migrations/*",
    "*/__main__.py",
    "myapp/vendor/*",
]
branch = true  # measure branch coverage in addition to line coverage

[tool.coverage.report]
fail_under = 80
show_missing = true
skip_covered = false  # show 100% files in report (set true to hide them)
precision = 1

[tool.coverage.html]
directory = "htmlcov"
title = "My App Coverage"

[tool.coverage.xml]
output = "coverage.xml"
```

### .coveragerc (Legacy)

```ini
[run]
source = myapp
omit =
    tests/*
    */migrations/*
branch = True

[report]
fail_under = 80
show_missing = True
```

## Branch Coverage

Line coverage only confirms a line executed; branch coverage confirms both paths of a conditional were taken:

```python
def validate(x):
    if x > 0:       # line 1 — always hit
        return True  # line 2 — hit when x > 0
    return False     # line 3 — missed if tests only use x > 0
```

Without branch coverage: 3/3 lines = 100%. With branch coverage: the `if x > 0 → True` branch is only tested if both `x > 0` and `x <= 0` test cases exist.

Enable with `branch = true` in config or `--cov-branch` flag.

## Reading the Gap Report

```
Name                    Stmts   Miss Branch BrPart  Cover   Missing
calculator.py              24      4      8      2    75%   18-22, 45
utils/formatter.py         12      2      4      1    67%   8-10
```

- **Stmts** — total executable statements
- **Miss** — unexecuted statements
- **Branch** — total branch pairs (only with `branch = true`)
- **BrPart** — branches partially covered (one direction tested)
- **Missing** — line ranges never executed

When targeting gap lines, `18-22` means the `if/else` block spanning those lines has an untested path.

## Parsing for CI / Agent Handoff

```bash
# Extract total coverage percentage
python -c "
import json, sys
data = json.load(open('coverage.json'))
total = data['totals']['percent_covered']
print(f'{total:.1f}%')
"

# List files below threshold
python -c "
import json
data = json.load(open('coverage.json'))
threshold = 80
for fname, info in data['files'].items():
    pct = info['summary']['percent_covered']
    missing = info['missing_lines']
    if pct < threshold:
        print(f'{pct:.0f}%  {fname}  missing: {missing}')
"
```

## Parallel Test Runs

When running pytest with `pytest-xdist`, each worker writes its own `.coverage.*` file. Combine them before reporting:

```bash
pytest --cov=myapp --cov-parallel -n auto tests/
coverage combine  # merge all .coverage.* files
coverage report
```

Add to `.coveragerc`:
```ini
[run]
parallel = True
```

## GitHub Actions Pattern

```yaml
- name: Install dependencies
  run: pip install pytest pytest-cov

- name: Run tests with coverage
  run: |
    pytest --cov=myapp \
           --cov-report=xml \
           --cov-report=term-missing \
           --cov-fail-under=80 \
           tests/
  env:
    QT_QPA_PLATFORM: offscreen

- name: Upload coverage report
  uses: actions/upload-artifact@v4
  with:
    name: coverage-html
    path: htmlcov/
    if-no-files-found: warn

# Optional: Post coverage summary to PR
- name: Coverage summary
  run: |
    python -c "
    import json
    d = json.load(open('coverage.json'))
    t = d['totals']
    print(f\"Coverage: {t['percent_covered']:.1f}% ({t['covered_lines']}/{t['num_statements']} lines)\")
    "
```
