#!/usr/bin/env node
// metrics.ts — CLI utility for structured LOC counting and diff summaries.
// Run via: npx tsx plugins/autonomous-refactor/src/metrics.ts <command> [args]
// Commands:
//   loc <file>            → {file, loc, blank_lines, comment_lines, total_lines}
//   diff <before> <after> → {added_lines, removed_lines, changed_functions, summary_text}
// Called by report-generator agent and snapshot-metrics.sh as an optional precision layer.
// Falls back gracefully if files don't exist (returns null fields, non-zero exit).

import { readFileSync } from "fs";
import { basename } from "path";

interface LocResult {
  file: string;
  total_lines: number;
  loc: number;
  blank_lines: number;
  comment_lines: number;
}

interface DiffResult {
  before_file: string;
  after_file: string;
  added_lines: number;
  removed_lines: number;
  net_change: number;
  changed_function_count: number;
  summary_text: string;
}

function countLoc(filePath: string): LocResult {
  const content = readFileSync(filePath, "utf8");
  const lines = content.split("\n");

  // Language detection from extension for comment pattern selection
  const ext = filePath.split(".").pop()?.toLowerCase() ?? "";
  const isTs = ["ts", "tsx", "js", "jsx"].includes(ext);
  const isPy = ext === "py";

  let blankLines = 0;
  let commentLines = 0;

  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed === "") {
      blankLines++;
    } else if (isTs && (trimmed.startsWith("//") || trimmed.startsWith("*") || trimmed.startsWith("/*"))) {
      commentLines++;
    } else if (isPy && trimmed.startsWith("#")) {
      commentLines++;
    }
  }

  const totalLines = lines.length;
  const loc = totalLines - blankLines - commentLines;

  return {
    file: filePath,
    total_lines: totalLines,
    loc,
    blank_lines: blankLines,
    comment_lines: commentLines,
  };
}

function diffFiles(beforePath: string, afterPath: string): DiffResult {
  const before = readFileSync(beforePath, "utf8").split("\n");
  const after = readFileSync(afterPath, "utf8").split("\n");

  const beforeSet = new Set(before);
  const afterSet = new Set(after);

  // Lines present in after but not before = added
  const added = after.filter((l) => !beforeSet.has(l)).length;
  // Lines present in before but not after = removed
  const removed = before.filter((l) => !afterSet.has(l)).length;

  // Rough changed-function detection: count function/def declarations that differ
  const funcPattern = /^\s*(export\s+)?(async\s+)?function\s+\w+|^\s*def\s+\w+/;
  const beforeFuncs = new Set(before.filter((l) => funcPattern.test(l)).map((l) => l.trim()));
  const afterFuncs = new Set(after.filter((l) => funcPattern.test(l)).map((l) => l.trim()));
  const changedFunctions = [...afterFuncs].filter((f) => !beforeFuncs.has(f)).length +
    [...beforeFuncs].filter((f) => !afterFuncs.has(f)).length;

  const net = after.length - before.length;
  const netLabel = net >= 0 ? `+${net}` : `${net}`;
  const summaryText =
    `${basename(afterPath)}: ${added} lines added, ${removed} lines removed (net ${netLabel}). ` +
    `${changedFunctions} function signature(s) changed.`;

  return {
    before_file: beforePath,
    after_file: afterPath,
    added_lines: added,
    removed_lines: removed,
    net_change: net,
    changed_function_count: changedFunctions,
    summary_text: summaryText,
  };
}

function main(): void {
  const [, , command, ...args] = process.argv;

  if (!command || command === "--help" || command === "-h") {
    console.error("Usage: metrics.ts <command> [args]");
    console.error("  loc <file>            Print LOC breakdown as JSON");
    console.error("  diff <before> <after> Print diff summary as JSON");
    process.exit(0);
  }

  try {
    if (command === "loc") {
      const [file] = args;
      if (!file) {
        console.error("ERROR: loc requires a file argument");
        process.exit(1);
      }
      console.log(JSON.stringify(countLoc(file), null, 2));
    } else if (command === "diff") {
      const [before, after] = args;
      if (!before || !after) {
        console.error("ERROR: diff requires two file arguments: <before> <after>");
        process.exit(1);
      }
      console.log(JSON.stringify(diffFiles(before, after), null, 2));
    } else {
      console.error(`ERROR: unknown command '${command}'. Use 'loc' or 'diff'.`);
      process.exit(1);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`ERROR: ${message}`);
    process.exit(1);
  }
}

main();
