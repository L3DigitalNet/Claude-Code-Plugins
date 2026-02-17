/**
 * check_patterns tool - Check for anti-patterns and deprecations
 */

import { readFile, readdir, stat } from "fs/promises";
import { existsSync } from "fs";
import { join } from "path";
import type { CheckPatternsInput, CheckPatternsOutput, PatternIssue } from "../types.js";

interface Pattern {
  name: string;
  pattern: RegExp;
  message: string;
  severity: "error" | "warning";
  fix?: string;
}

const PATTERNS: Pattern[] = [
  // Storage patterns
  {
    name: "hass.data[DOMAIN]",
    pattern: /hass\.data\s*\[\s*DOMAIN\s*\]/g,
    message: "Use entry.runtime_data instead of hass.data[DOMAIN]",
    severity: "warning",
    fix: "entry.runtime_data",
  },
  {
    name: "hass.data.setdefault",
    pattern: /hass\.data\.setdefault\s*\(\s*DOMAIN/g,
    message: "Use entry.runtime_data instead of hass.data.setdefault(DOMAIN, ...)",
    severity: "warning",
  },

  // Old ServiceInfo imports
  {
    name: "old-zeroconf-import",
    pattern: /from homeassistant\.components\.zeroconf import.*ServiceInfo/g,
    message: "Import from homeassistant.helpers.service_info.zeroconf (changed in 2025.1)",
    severity: "warning",
  },
  {
    name: "old-ssdp-import",
    pattern: /from homeassistant\.components\.ssdp import.*ServiceInfo/g,
    message: "Import from homeassistant.helpers.service_info.ssdp (changed in 2025.1)",
    severity: "warning",
  },
  {
    name: "old-dhcp-import",
    pattern: /from homeassistant\.components\.dhcp import.*ServiceInfo/g,
    message: "Import from homeassistant.helpers.service_info.dhcp (changed in 2025.1)",
    severity: "warning",
  },

  // Blocking I/O
  {
    name: "blocking-requests",
    pattern: /\brequests\.(get|post|put|delete|patch|head)\s*\(/g,
    message: "Use aiohttp instead of blocking requests library",
    severity: "error",
  },
  {
    name: "blocking-sleep",
    pattern: /\btime\.sleep\s*\(/g,
    message: "Use asyncio.sleep instead of blocking time.sleep",
    severity: "error",
  },
  {
    name: "blocking-urlopen",
    pattern: /\burllib\.request\.urlopen\s*\(/g,
    message: "Use aiohttp instead of blocking urllib",
    severity: "error",
  },

  // Deprecated type syntax
  {
    name: "typing-List",
    pattern: /\bList\s*\[/g,
    message: "Use list[] instead of List[] (Python 3.9+)",
    severity: "warning",
  },
  {
    name: "typing-Dict",
    pattern: /\bDict\s*\[/g,
    message: "Use dict[] instead of Dict[] (Python 3.9+)",
    severity: "warning",
  },
  {
    name: "typing-Optional",
    pattern: /\bOptional\s*\[/g,
    message: "Use X | None instead of Optional[X] (Python 3.10+)",
    severity: "warning",
  },
  {
    name: "typing-Union",
    pattern: /\bUnion\s*\[/g,
    message: "Use X | Y instead of Union[X, Y] (Python 3.10+)",
    severity: "warning",
  },
  {
    name: "typing-Tuple",
    pattern: /\bTuple\s*\[/g,
    message: "Use tuple[] instead of Tuple[] (Python 3.9+)",
    severity: "warning",
  },
  {
    name: "typing-Set",
    pattern: /\bSet\s*\[/g,
    message: "Use set[] instead of Set[] (Python 3.9+)",
    severity: "warning",
  },

  // Missing annotations
  {
    name: "missing-future-annotations",
    pattern: /^(?!from __future__ import annotations).*\bdef\b/gm,
    message: "Add 'from __future__ import annotations' at top of file",
    severity: "warning",
  },

  // Blocking I/O - additional
  {
    name: "blocking-open",
    pattern: /\bopen\s*\([^)]*\)\s*\.\s*read\s*\(/g,
    message: "Use aiofiles for async file operations",
    severity: "warning",
  },

  // Old USB import
  {
    name: "old-usb-import",
    pattern: /from homeassistant\.components\.usb import.*ServiceInfo/g,
    message: "Import from homeassistant.helpers.service_info.usb (changed in 2025.1)",
    severity: "warning",
  },

  // Deprecated async patterns
  {
    name: "asyncio-coroutine",
    pattern: /@asyncio\.coroutine/g,
    message: "Use 'async def' instead of @asyncio.coroutine decorator",
    severity: "error",
  },

  // Options flow patterns
  {
    name: "options-flow-init",
    pattern: /class\s+\w*OptionsFlow[^:]*:[^}]*def\s+__init__\s*\([^)]*config_entry/g,
    message: "OptionsFlow __init__ storing config_entry is deprecated (HA 2025.12+)",
    severity: "warning",
  },

  // Coordinator patterns
  {
    name: "coordinator-no-generic",
    pattern: /class\s+\w+Coordinator\s*\(\s*DataUpdateCoordinator\s*\)/g,
    message: "DataUpdateCoordinator should have a generic type parameter",
    severity: "warning",
  },

  // Service registration in wrong place
  {
    name: "service-in-setup-entry",
    pattern: /async_setup_entry[^}]*hass\.services\.async_register/gs,
    message: "Services should be registered in async_setup, not async_setup_entry",
    severity: "warning",
  },
];

async function checkFile(filePath: string): Promise<PatternIssue[]> {
  const issues: PatternIssue[] = [];

  const content = await readFile(filePath, "utf-8");
  const lines = content.split("\n");

  for (const pattern of PATTERNS) {
    // Reset regex state
    pattern.pattern.lastIndex = 0;

    let match;
    while ((match = pattern.pattern.exec(content)) !== null) {
      // Find line number
      const beforeMatch = content.slice(0, match.index);
      const lineNum = (beforeMatch.match(/\n/g) || []).length + 1;

      // Skip if in comment
      const line = lines[lineNum - 1] || "";
      if (line.trim().startsWith("#")) {
        continue;
      }

      issues.push({
        file: filePath,
        line: lineNum,
        pattern: pattern.name,
        message: pattern.message,
        severity: pattern.severity,
        fix: pattern.fix,
      });
    }
  }

  return issues;
}

async function checkDirectory(dirPath: string): Promise<PatternIssue[]> {
  const issues: PatternIssue[] = [];
  const excludeDirs = new Set([".git", "__pycache__", ".venv", "venv", "node_modules"]);

  async function walk(dir: string): Promise<void> {
    const entries = await readdir(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = join(dir, entry.name);

      if (entry.isDirectory()) {
        if (!excludeDirs.has(entry.name)) {
          await walk(fullPath);
        }
      } else if (entry.isFile() && entry.name.endsWith(".py")) {
        const fileIssues = await checkFile(fullPath);
        issues.push(...fileIssues);
      }
    }
  }

  await walk(dirPath);
  return issues;
}

export async function handleCheckPatterns(
  input: CheckPatternsInput
): Promise<CheckPatternsOutput> {
  if (!existsSync(input.path)) {
    throw new Error(`Path not found: ${input.path}`);
  }

  const pathStat = await stat(input.path);
  let issues: PatternIssue[];

  if (pathStat.isDirectory()) {
    issues = await checkDirectory(input.path);
  } else {
    issues = await checkFile(input.path);
  }

  // Sort by severity (errors first) then by file/line
  issues.sort((a, b) => {
    if (a.severity !== b.severity) {
      return a.severity === "error" ? -1 : 1;
    }
    if (a.file !== b.file) {
      return a.file.localeCompare(b.file);
    }
    return a.line - b.line;
  });

  const summary = {
    errors: issues.filter((i) => i.severity === "error").length,
    warnings: issues.filter((i) => i.severity === "warning").length,
  };

  return {
    issues,
    summary,
  };
}
