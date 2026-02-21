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
      input[field] = [];
    } else if (prop.type === 'object') {
      input[field] = {};
    } else {
      input[field] = null;
    }
  }
  return input;
}
