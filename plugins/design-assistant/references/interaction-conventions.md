# Interaction Conventions

**Rule: Convert every 2-4 option decision point to `AskUserQuestion`.**

This applies universally, including to code blocks in templates that display (A), (B), (C), (D) options. Those blocks define the *content*; you convert them to `AskUserQuestion` at runtime. Do not reproduce them as formatted text.

How to convert a code block to `AskUserQuestion`:
- **question**: Use the prompt or question text from the block header
- **header**: A 12-character-or-shorter label (e.g., "Entry Point", "Verdict", "Proceed?", "Structure")
- **options**: Each (A)/(B)/(C)/(D) becomes one `{label, description}` pair. Option letter text as the label, surrounding context as the description. Maximum 4 options.
- Do not add a redundant "(X) Other" since `AskUserQuestion` includes this automatically.

**For 5 or more options:** Present as formatted text, not `AskUserQuestion`.

**Never convert:** Pause State Snapshots, diff blocks, phase headers, and informational inventory blocks. These are output, not menus.
