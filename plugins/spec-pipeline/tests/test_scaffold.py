from specpipe import scaffold


def _fake_plugin(tmp_path, monkeypatch):
    root = tmp_path / "plugin"
    (root / "templates").mkdir(parents=True)
    (root / "templates" / "phase-plan.md").write_text("# Phase Plan — {{PROJECT}}\n",
                                                      encoding="utf-8")
    monkeypatch.setattr(scaffold, "PLUGIN_ROOT", root)
    target = tmp_path / "project"
    target.mkdir()
    return target


def test_init_creates_layout(tmp_path, monkeypatch):
    target = _fake_plugin(tmp_path, monkeypatch)
    scaffold.init_project(target)
    assert (target / "docs" / "handoff" / "audit").is_dir()
    assert (target / "docs" / "handoff" / "phase-plan.md").read_text(
        encoding="utf-8").startswith("# Phase Plan")
    assert ".spec-pipeline/" in (target / ".gitignore").read_text(encoding="utf-8")


def test_init_never_overwrites(tmp_path, monkeypatch):
    target = _fake_plugin(tmp_path, monkeypatch)
    plan = target / "docs" / "handoff" / "phase-plan.md"
    plan.parent.mkdir(parents=True)
    plan.write_text("existing content\n", encoding="utf-8")
    actions = scaffold.init_project(target)
    assert plan.read_text(encoding="utf-8") == "existing content\n"
    assert any("skipped" in a for a in actions)


def test_gitignore_appended_once(tmp_path, monkeypatch):
    target = _fake_plugin(tmp_path, monkeypatch)
    (target / ".gitignore").write_text("node_modules", encoding="utf-8")  # no newline
    scaffold.init_project(target)
    scaffold.init_project(target)
    content = (target / ".gitignore").read_text(encoding="utf-8")
    assert content.count(".spec-pipeline/") == 1
    assert "node_modules\n.spec-pipeline/\n" in content


def test_custom_handoff_dir(tmp_path, monkeypatch):
    target = _fake_plugin(tmp_path, monkeypatch)
    scaffold.init_project(target, handoff_dir="notes/state")
    assert (target / "notes" / "state" / "audit").is_dir()
    assert (target / "notes" / "state" / "phase-plan.md").exists()
    assert not (target / "docs").exists()
