# {{PROJECT}} Phase {{N}} Implementation Plan

**Goal:** {{One sentence: what this phase builds.}}

**Architecture:** {{2-3 sentences naming the key constructs.}}

**Tech Stack:** {{Language, runtime, key tools.}}

**Spec:** {{phase-spec path}} (defers to {{master path}}; master governs on conflict)

## Global Constraints

- {{Project-wide requirements binding every task: version floors, typing rules, the exact verification-gate command(s).}}

## File Structure

| Symbol           | Kind               | Introduced |
| ---------------- | ------------------ | ---------- |
| `{{new_symbol}}` | {{function/class}} | Task 1     |

### Task 1: {{Component}}

**Files:**

- Create: `{{exact/path}}`
- Test: `{{tests/exact/path}}`

**Interfaces:**

- Consumes: {{existing symbols this task relies on}}
- Produces: `{{new_symbol}}({{args}}) -> {{type}}` — consumed by {{later task}}

- [ ] **Step 1: Write the failing test**

```python
def test_{{behavior}}():
    assert {{new_symbol}}({{adversarial_input}}) == {{expected}}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `{{exact test command}}` Expected: FAIL with "{{expected failure, e.g. name not defined}}"

- [ ] **Step 3: Implement {{new_symbol}}**

```python
{{complete minimal implementation}}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `{{exact test command}}`

- [ ] **Step 5: Run the full verification gate; commit**

```bash
{{verification gate command}}
git add {{explicit paths}}
git commit -m "{{imperative message}}"
```
