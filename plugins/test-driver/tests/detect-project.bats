#!/usr/bin/env bats
# Tests for detect-project.sh
# Validates project type detection from marker files.

load helpers

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "empty directory: project_type is null, confidence is none" {
    mkdir -p "$TEST_TMPDIR/empty-proj"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/empty-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] is None, f'expected null, got {d[\"project_type\"]}'
assert d['confidence'] == 'none', f'expected none, got {d[\"confidence\"]}'
"
}

@test "directory with pyproject.toml: detects python type" {
    mkdir -p "$TEST_TMPDIR/py-proj"
    # Include a known framework so confidence stays high
    cat > "$TEST_TMPDIR/py-proj/pyproject.toml" <<'EOF'
[project]
dependencies = ["fastapi"]
EOF
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/py-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'python-fastapi', f'expected python-fastapi, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
assert 'pyproject.toml' in d['markers_found']
"
}

@test "directory with Package.swift: detects swift-swiftui" {
    mkdir -p "$TEST_TMPDIR/swift-proj"
    touch "$TEST_TMPDIR/swift-proj/Package.swift"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/swift-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'swift-swiftui', f'expected swift-swiftui, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
"
}

@test "directory with package.json: detects javascript" {
    mkdir -p "$TEST_TMPDIR/js-proj"
    echo '{}' > "$TEST_TMPDIR/js-proj/package.json"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/js-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'javascript', f'expected javascript, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
"
}

@test "directory with package.json + tsconfig.json: detects typescript" {
    mkdir -p "$TEST_TMPDIR/ts-proj"
    echo '{}' > "$TEST_TMPDIR/ts-proj/package.json"
    echo '{}' > "$TEST_TMPDIR/ts-proj/tsconfig.json"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/ts-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'typescript', f'expected typescript, got {d[\"project_type\"]}'
"
}

@test "directory with .claude-plugin/plugin.json: detects claude-plugin" {
    mkdir -p "$TEST_TMPDIR/plugin-proj/.claude-plugin"
    echo '{"name":"test"}' > "$TEST_TMPDIR/plugin-proj/.claude-plugin/plugin.json"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/plugin-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'claude-plugin', f'expected claude-plugin, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
"
}

@test "first marker wins: pyproject.toml AND package.json detects python" {
    mkdir -p "$TEST_TMPDIR/multi-proj"
    # Use django so sub-classification keeps a python-* type
    cat > "$TEST_TMPDIR/multi-proj/pyproject.toml" <<'EOF'
[project]
dependencies = ["django"]
EOF
    echo '{}' > "$TEST_TMPDIR/multi-proj/package.json"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/multi-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
# python is first in marker list, so it wins
assert d['project_type'].startswith('python'), f'expected python*, got {d[\"project_type\"]}'
assert 'pyproject.toml' in d['markers_found']
assert 'package.json' in d['markers_found']
"
}

@test "Python with django in pyproject.toml deps: detects python-django" {
    mkdir -p "$TEST_TMPDIR/django-proj"
    cat > "$TEST_TMPDIR/django-proj/pyproject.toml" <<'EOF'
[project]
dependencies = ["django", "django-rest-framework"]
EOF
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/django-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'python-django', f'expected python-django, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
"
}

@test "Python with pyside6 in pyproject.toml deps: detects python-pyside6" {
    mkdir -p "$TEST_TMPDIR/qt-proj"
    cat > "$TEST_TMPDIR/qt-proj/pyproject.toml" <<'EOF'
[project]
dependencies = ["pyside6"]
EOF
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/qt-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'python-pyside6', f'expected python-pyside6, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
"
}

@test "Python with hacs.json present: detects home-assistant" {
    mkdir -p "$TEST_TMPDIR/ha-proj"
    cat > "$TEST_TMPDIR/ha-proj/pyproject.toml" <<'EOF'
[project]
dependencies = []
EOF
    echo '{}' > "$TEST_TMPDIR/ha-proj/hacs.json"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/ha-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'home-assistant', f'expected home-assistant, got {d[\"project_type\"]}'
"
}

@test "Generic Python (no framework markers): confidence is medium" {
    mkdir -p "$TEST_TMPDIR/generic-py"
    cat > "$TEST_TMPDIR/generic-py/pyproject.toml" <<'EOF'
[project]
dependencies = ["requests", "click"]
EOF
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/generic-py"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'python', f'expected python, got {d[\"project_type\"]}'
assert d['confidence'] == 'medium', f'expected medium, got {d[\"confidence\"]}'
"
}

@test "Cargo.toml present: detects rust" {
    mkdir -p "$TEST_TMPDIR/rust-proj"
    cat > "$TEST_TMPDIR/rust-proj/Cargo.toml" <<'EOF'
[package]
name = "my-crate"
version = "0.1.0"
EOF
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/rust-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'rust', f'expected rust, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
assert 'Cargo.toml' in d['markers_found']
"
}

@test "go.mod detects go project" {
    mkdir -p "$TEST_TMPDIR/go-proj"
    printf 'module example.com/mymod\n\ngo 1.21\n' > "$TEST_TMPDIR/go-proj/go.mod"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/go-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'go', f'expected go, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
assert 'go.mod' in d['markers_found']
"
}

@test "pom.xml detects java project" {
    mkdir -p "$TEST_TMPDIR/java-proj"
    printf '<project><modelVersion>4.0.0</modelVersion></project>\n' > "$TEST_TMPDIR/java-proj/pom.xml"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/java-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'java', f'expected java, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
assert 'pom.xml' in d['markers_found']
"
}

@test "setup.py detects python project" {
    mkdir -p "$TEST_TMPDIR/setuppy-proj"
    printf 'from setuptools import setup\nsetup(name=\"mypkg\")\n' > "$TEST_TMPDIR/setuppy-proj/setup.py"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/setuppy-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'].startswith('python'), f'expected python*, got {d[\"project_type\"]}'
assert 'setup.py' in d['markers_found']
"
}

@test "requirements.txt detects python project" {
    mkdir -p "$TEST_TMPDIR/reqs-proj"
    printf 'requests>=2.28\nclick\n' > "$TEST_TMPDIR/reqs-proj/requirements.txt"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/reqs-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'].startswith('python'), f'expected python*, got {d[\"project_type\"]}'
assert 'requirements.txt' in d['markers_found']
"
}

@test "secondary markers collected when multiple markers exist" {
    mkdir -p "$TEST_TMPDIR/multi-proj2"
    cat > "$TEST_TMPDIR/multi-proj2/pyproject.toml" <<'EOF'
[project]
dependencies = ["fastapi"]
EOF
    echo '{}' > "$TEST_TMPDIR/multi-proj2/package.json"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/multi-proj2"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d['secondary_markers']) > 0, 'expected secondary markers'
assert 'package.json' in d['secondary_markers']
"
}
