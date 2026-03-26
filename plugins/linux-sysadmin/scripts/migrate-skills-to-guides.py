#!/usr/bin/env python3
"""Migrate linux-sysadmin skills to guides directory.

Moves all skill directories (except sysadmin/) from skills/ to guides/,
renames SKILL.md to guide.md, strips YAML frontmatter, and adds a heading.
"""

import os
import shutil
import sys
import yaml

PLUGIN_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILLS_DIR = os.path.join(PLUGIN_ROOT, "skills")
GUIDES_DIR = os.path.join(PLUGIN_ROOT, "guides")

# The one skill that stays
KEEP_SKILLS = {"sysadmin"}


def strip_frontmatter_and_add_heading(content: str, topic: str) -> str:
    """Remove YAML frontmatter and add a markdown H1 heading."""
    # Extract name from frontmatter for the heading
    parts = content.split("---", 2)
    if len(parts) >= 3:
        try:
            fm = yaml.safe_load(parts[1])
            name = fm.get("name", topic)
        except yaml.YAMLError:
            name = topic
        body = parts[2].lstrip("\n")
    else:
        name = topic
        body = content

    return f"# {name}\n\n{body}"


def migrate():
    os.makedirs(GUIDES_DIR, exist_ok=True)

    topics = sorted(
        d
        for d in os.listdir(SKILLS_DIR)
        if os.path.isdir(os.path.join(SKILLS_DIR, d)) and d not in KEEP_SKILLS
    )

    moved = 0
    errors = []

    for topic in topics:
        src = os.path.join(SKILLS_DIR, topic)
        dst = os.path.join(GUIDES_DIR, topic)
        skill_md = os.path.join(src, "SKILL.md")

        if not os.path.exists(skill_md):
            errors.append(f"SKIP {topic}: no SKILL.md")
            continue

        # Read and transform SKILL.md
        with open(skill_md) as f:
            content = f.read()
        transformed = strip_frontmatter_and_add_heading(content, topic)

        # Move the directory
        shutil.move(src, dst)

        # Rename SKILL.md -> guide.md with transformed content
        old_path = os.path.join(dst, "SKILL.md")
        new_path = os.path.join(dst, "guide.md")
        with open(new_path, "w") as f:
            f.write(transformed)
        if os.path.exists(old_path) and old_path != new_path:
            os.remove(old_path)

        moved += 1

    print(f"Moved {moved} topics to guides/")
    if errors:
        print("Errors:")
        for e in errors:
            print(f"  {e}")

    return moved, errors


if __name__ == "__main__":
    moved, errors = migrate()
    if errors:
        sys.exit(1)
