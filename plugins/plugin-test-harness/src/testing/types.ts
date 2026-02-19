export type TestMode = 'mcp' | 'plugin';
export type TestType = 'single' | 'scenario' | 'hook-script' | 'validate' | 'exec';
export type GeneratedFrom = 'schema' | 'source_analysis' | 'documentation' | 'manual';

export interface ExpectBlock {
  success?: boolean;
  output_contains?: string;
  output_equals?: string;
  output_matches?: string;
  output_json?: unknown;
  output_json_contains?: unknown;
  error_contains?: string;
  exit_code?: number;
  stdout_contains?: string;
  stdout_matches?: string;
}

export interface StepDef {
  tool: string;
  input: Record<string, unknown>;
  expect?: ExpectBlock;
  capture?: Record<string, string>;  // varName -> JSONPath
}

export interface SetupStep {
  exec?: string;
  file?: { path: string; content: string };
}

export interface ValidateCheck {
  type: 'json-schema' | 'file-exists' | 'json-valid';
  file?: string;
  files?: string[];
}

export interface PthTest {
  id: string;        // generated: slugified name
  name: string;
  mode: TestMode;
  type: TestType;
  // MCP single
  tool?: string;
  input?: Record<string, unknown>;
  // MCP scenario
  steps?: StepDef[];
  // Plugin
  script?: string;
  stdin?: Record<string, unknown>;
  env?: Record<string, string>;
  checks?: ValidateCheck[];
  command?: string;  // for exec type
  // Common
  expect: ExpectBlock;
  setup?: SetupStep[];
  teardown?: SetupStep[];
  tags?: string[];
  generated_from?: GeneratedFrom;
  timeout_seconds?: number;
}

export type TestStatus = 'pending' | 'passing' | 'failing' | 'skipped';

export interface TestResult {
  testId: string;
  testName: string;
  status: TestStatus;
  iteration: number;
  durationMs?: number;
  failureReason?: string;
  claudeNotes?: string;   // Claude's diagnosis/observation
  recordedAt: string;     // ISO 8601
}
