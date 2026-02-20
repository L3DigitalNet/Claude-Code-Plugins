# Markdown Tightening

Read this file in full before beginning.

## Purpose

Rewrite instruction markdown files to be as token-efficient as possible without losing behavioral information. This skill operates on one file at a time. It does not evaluate plugin architecture or agent design — that is the job of CONTEXT_EFFICIENCY_REVIEW.md.

---

## The Standard

Every sentence in an instruction file must satisfy at least one of these three tests:

- **Defines a behavior:** tells Claude what to do, produce, or avoid
- **Constrains a choice:** limits the set of valid actions or outputs
- **Specifies a format:** describes the structure, schema, or shape of something

Any sentence that fails all three tests is waste. Cut it.

---

## Sentence-Level Rules

**No motivation.** Remove sentences that explain why Claude should care about an instruction. Claude does not need to be persuaded. "This is important because..." and "We want Claude to..." are always cuts.

**No restatement.** If a concept was defined earlier in the file, reference the name — do not restate the definition. If the same constraint appears twice, keep the cleaner instance and delete the other.

**No hedging.** Remove qualifiers that add length without adding precision. "Generally," "in most cases," "where possible," and "try to" should be cut unless the hedge is itself the constraint (i.e., the behavior is genuinely optional).

**No preamble.** Section headers should be followed immediately by instructions. Remove sentences that announce what the section is about to say.

**Prefer imperatives.** Passive constructions and noun-heavy phrases cost more tokens than direct verbs. "The output should be structured as..." becomes "Structure output as..." "It is important that Claude avoids..." becomes "Never..."

**Consolidate lists.** If a bulleted list contains items that could be expressed as a single sentence with inline enumeration, collapse it. Reserve lists for genuinely parallel, enumerable items where the list structure itself carries meaning.

---

## Process

### Step 1 — Inventory

Read the target file in full. Count the sections and estimate the total number of sentences. Identify which sections are likely to have the most waste (motivation-heavy introductions, repeated definitions, explanatory asides).

Report the inventory: section names, sentence count per section, and your assessment of where the most waste lives. Ask the user to confirm before proceeding.

### Step 2 — First Pass: Cut

Work through the file section by section. Apply the three-test standard to every sentence. Mark sentences for deletion if they fail all three tests. Do not rewrite yet — only cut. Preserve the structure and order of what remains.

Present the cut version as a diff or clearly marked redline so the user can see exactly what was removed. Ask for confirmation before proceeding.

### Step 3 — Second Pass: Compress

Rewrite every surviving sentence for maximum compression. Convert passive constructions to imperatives. Collapse multi-sentence statements of a single idea into one sentence. Collapse lists where inline enumeration is cleaner. Combine related constraints into single compound sentences where the result is still clear.

Do not change meaning. If compression would require ambiguity, keep the longer form and note it.

Present the compressed version. Show the before and after word counts for each section. Ask for confirmation before proceeding.

### Step 4 — Third Pass: Structure

Review the compressed file for structural efficiency. Confirm that YAML or markdown tables are used for any structured data that survived as prose. Confirm that section headers are necessary — remove any header whose section could be folded into an adjacent section without confusion. Confirm that the file's reading order matches the order Claude will need the information during execution.

Present the final version. State the total word count reduction as a percentage. Ask for explicit approval before writing the file.

### Step 5 — Write

Overwrite the target file with the approved version. Confirm the write and state the final word count and reduction percentage.

---

## What Not to Cut

Do not cut content that looks like explanation but is actually constraint. "Do this because the output is consumed by a machine parser that expects schema X" is a constraint — it tells Claude something that changes what it does. Test carefully before cutting anything that contains the word "because."

Do not cut examples if the example is the only way to make an ambiguous instruction unambiguous. A concrete example that resolves genuine ambiguity earns its tokens. An example that illustrates something already clear does not.

Do not cut warning or prohibition statements even if they seem obvious. Explicit prohibitions are cheaper than the cost of Claude inferring a boundary incorrectly.

---

## Uncertainty Protocol

If cutting or compressing a sentence would change its meaning in a way you cannot resolve, keep the original, flag it with a note, and ask the user for clarification. Do not guess at intent.
