// src/testing/generator.ts
import type { PthTest } from './types.js';
import type { ToolSchema } from '../shared/source-analyzer.js';
import { slugify } from './utils.js';

export interface GenerateMcpOptions {
  pluginPath: string;
  toolSchemas: ToolSchema[];
  includeEdgeCases?: boolean;
}

export async function generateMcpTests(options: GenerateMcpOptions): Promise<PthTest[]> {
  const tests: PthTest[] = [];
  const includeEdgeCases = options.includeEdgeCases ?? true;

  for (const tool of options.toolSchemas) {
    // Tools requiring a live git SHA can't be tested with a standalone call — generate a
    // two-step scenario that commits a stub file first and captures the hash for step 2.
    if (requiresRealCommit(tool)) {
      tests.push(buildCommitScenarioTest(tool, options.pluginPath));
      continue;
    }

    // Test 1: valid input (using required fields with minimal values)
    const validInput = buildValidInput(tool, options.pluginPath);
    tests.push({
      id: slugify(`${tool.name}_valid_input`),
      name: `${tool.name} — valid input`,
      mode: 'mcp',
      type: 'single',
      tool: tool.name,
      input: validInput,
      expect: { success: true },
      generated_from: 'schema',
      timeout_seconds: 10,
    });

    // Test 2: missing required field (if any required fields exist)
    if (includeEdgeCases) {
      const required = tool.inputSchema?.required ?? [];
      if (required.length > 0) {
        const missingInput = { ...validInput };
        delete missingInput[required[0]];
        tests.push({
          id: slugify(`${tool.name}_missing_required`),
          name: `${tool.name} — missing required field "${required[0]}"`,
          mode: 'mcp',
          type: 'single',
          tool: tool.name,
          input: missingInput,
          expect: { success: false },
          generated_from: 'schema',
          timeout_seconds: 10,
        });
      }
    }
  }

  return tests;
}

export function generatePluginTests(hookScripts: string[]): PthTest[] {
  const tests: PthTest[] = [];

  for (const script of hookScripts) {
    tests.push({
      id: slugify(`validate_${script}`),
      name: `${script} — script exists and is readable`,
      mode: 'plugin',
      type: 'validate',
      checks: [{ type: 'file-exists', files: [script] }],
      expect: {},   // validate tests have no output expectations — empty ExpectBlock
      generated_from: 'source_analysis',
    });
  }

  return tests;
}

function buildValidInput(tool: ToolSchema, pluginPath: string): Record<string, unknown> {
  const input: Record<string, unknown> = {};
  const props = tool.inputSchema?.properties ?? {};
  const required = tool.inputSchema?.required ?? [];

  for (const field of required) {
    const prop = props[field];
    if (!prop) { input[field] = ''; continue; }
    const fieldLower = field.toLowerCase();
    if (prop.type === 'string') {
      if (prop.enum) {
        input[field] = prop.enum[0];
      } else if (fieldLower.includes('path') || fieldLower.includes('dir')) {
        // Filesystem path fields require a real directory — use the plugin under test
        input[field] = pluginPath;
      } else if (fieldLower === 'branch') {
        // Git branch fields — use a safe, common default
        input[field] = 'main';
      } else if (fieldLower.includes('hash') || fieldLower.includes('sha') || fieldLower === 'commit') {
        // Git SHAs require 7–40 hex characters — use a realistic-format placeholder
        input[field] = 'abc1234def5678901234567890123456789012';
      } else if (fieldLower === 'yaml') {
        // YAML fields require structurally valid content with at minimum a name field
        input[field] = 'name: generated-test\nmode: mcp\ntool: example\nexpect:\n  success: true';
      } else {
        input[field] = 'test-value';
      }
    } else if (prop.type === 'number' || prop.type === 'integer') {
      input[field] = 1;
    } else if (prop.type === 'boolean') {
      input[field] = true;
    } else if (prop.type === 'array') {
      const minItems = typeof prop.minItems === 'number' ? prop.minItems : 0;
      // Respect minItems — an empty array will fail validation when minItems > 0
      input[field] = minItems > 0 ? [buildArrayItemStub(prop.items)] : [];
    } else if (prop.type === 'object') {
      input[field] = {};
    } else {
      input[field] = null;
    }
  }
  return input;
}

// True when any required string field is a git commit SHA — these fields can only be satisfied
// by a real commit in the current repo, so a standalone "valid input" test will always fail.
function requiresRealCommit(tool: ToolSchema): boolean {
  const required = tool.inputSchema?.required ?? [];
  const props = tool.inputSchema?.properties ?? {};
  return required.some(field => {
    const prop = props[field];
    if (!prop || prop.type !== 'string') return false;
    const fl = field.toLowerCase();
    return fl.includes('hash') || fl.includes('sha') || fl === 'commit';
  });
}

// Generates a two-step scenario: commit a stub file with pth_apply_fix, capture the hash,
// then call the target tool with the real hash. Avoids "bad revision" failures from fake SHAs.
function buildCommitScenarioTest(tool: ToolSchema, pluginPath: string): PthTest {
  const required = tool.inputSchema?.required ?? [];
  const props = tool.inputSchema?.properties ?? {};
  const hashField = required.find(f => {
    const fl = f.toLowerCase();
    return fl.includes('hash') || fl.includes('sha') || fl === 'commit';
  })!;

  // Build non-hash required fields using the same heuristics as single-tool tests
  const otherInput: Record<string, unknown> = {};
  for (const field of required) {
    if (field === hashField) continue;
    otherInput[field] = buildValidInput(
      { name: tool.name, inputSchema: { type: 'object', properties: { [field]: props[field] }, required: [field] } },
      pluginPath
    )[field];
  }

  return {
    id: slugify(`${tool.name}_valid_input`),
    name: `${tool.name} — valid input`,
    mode: 'mcp',
    type: 'scenario',
    steps: [
      {
        // Step 1: create a real commit so we have a hash to work with
        tool: 'pth_apply_fix',
        input: {
          files: [{ path: 'src/stub-for-scenario.ts', content: `// scenario stub for ${tool.name}\n` }],
          commitTitle: `test: stub commit for ${tool.name} scenario`,
        },
        expect: { success: true },
        // Claude extracts the short hash from "Fix committed: {hash} (iteration N)"
        capture: { [hashField]: 'text:Fix committed: (\\w+)' },
      },
      {
        // Step 2: call the target tool with the real captured hash
        tool: tool.name,
        input: { ...otherInput, [hashField]: `\${${hashField}}` },
        expect: { success: true },
      },
    ],
    expect: { success: true },
    generated_from: 'schema',
    timeout_seconds: 30,
  };
}

// Builds a single stub item for an array field that requires at least one element.
// Uses field-name heuristics on the item's own properties to produce realistic values.
function buildArrayItemStub(itemSchema: Record<string, unknown> | undefined): Record<string, unknown> {
  if (!itemSchema || itemSchema['type'] !== 'object') return {};
  const stub: Record<string, unknown> = {};
  const itemProps = (itemSchema['properties'] as Record<string, Record<string, unknown>>) ?? {};
  const itemRequired = (itemSchema['required'] as string[]) ?? Object.keys(itemProps);
  for (const itemField of itemRequired) {
    const itemProp = itemProps[itemField] ?? {};
    const fl = itemField.toLowerCase();
    if (itemProp['type'] === 'string') {
      if (fl === 'path' || fl.includes('path')) stub[itemField] = 'src/stub.ts';
      else if (fl === 'content') stub[itemField] = '// stub file content\n';
      else stub[itemField] = 'test-value';
    } else {
      stub[itemField] = null;
    }
  }
  return stub;
}
