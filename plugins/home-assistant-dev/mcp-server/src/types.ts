/**
 * Type definitions for HA Dev MCP Server
 */

// Configuration types
export interface ServerConfig {
  homeAssistant: {
    url: string;
    token: string;
    verifySsl: boolean;
  };
  safety: {
    allowServiceCalls: boolean;
    blockedServices: string[];
    requireDryRun: boolean;
  };
  cache: {
    docsTtlHours: number;
    statesTtlSeconds: number;
  };
  features: {
    enableDocsTools: boolean;
    enableHaTools: boolean;
    enableValidationTools: boolean;
  };
}

// Home Assistant types
export interface HaState {
  entity_id: string;
  state: string;
  attributes: Record<string, unknown>;
  last_changed: string;
  last_updated: string;
  context: {
    id: string;
    parent_id: string | null;
    user_id: string | null;
  };
}

export interface HaService {
  domain: string;
  service: string;
  name: string;
  description: string;
  fields: Record<string, HaServiceField>;
  target?: HaServiceTarget;
}

export interface HaServiceField {
  name: string;
  description: string;
  required: boolean;
  example?: unknown;
  selector?: Record<string, unknown>;
}

export interface HaServiceTarget {
  entity?: { domain?: string[] };
  device?: { integration?: string[] };
  area?: Record<string, unknown>;
}

export interface HaDevice {
  id: string;
  name: string;
  name_by_user: string | null;
  manufacturer: string | null;
  model: string | null;
  sw_version: string | null;
  hw_version: string | null;
  via_device_id: string | null;
  area_id: string | null;
  config_entries: string[];
  identifiers: Array<[string, string]>;
}

export interface HaLogEntry {
  timestamp: string;
  level: "DEBUG" | "INFO" | "WARNING" | "ERROR" | "CRITICAL";
  source: string;
  message: string;
}

// Tool input/output types
export interface HaConnectInput {
  url: string;
  token: string;
  verify_ssl?: boolean;
}

export interface HaConnectOutput {
  connected: boolean;
  version: string;
  location: string;
  components: string[];
}

export interface HaGetStatesInput {
  domain?: string;
  entity_id?: string;
  area?: string;
}

export interface HaGetStatesOutput {
  entities: HaState[];
  count: number;
}

export interface HaGetServicesInput {
  domain?: string;
}

export interface HaGetServicesOutput {
  services: HaService[];
}

export interface HaCallServiceInput {
  domain: string;
  service: string;
  data?: Record<string, unknown>;
  target?: {
    entity_id?: string | string[];
    device_id?: string | string[];
    area_id?: string | string[];
  };
  dry_run?: boolean;
}

export interface HaCallServiceOutput {
  success: boolean;
  dry_run: boolean;
  result?: unknown;
  error?: string;
}

export interface HaGetDevicesInput {
  manufacturer?: string;
  model?: string;
  integration?: string;
}

export interface HaGetDevicesOutput {
  devices: HaDevice[];
}

export interface HaGetLogsInput {
  domain?: string;
  level?: "DEBUG" | "INFO" | "WARNING" | "ERROR";
  lines?: number;
  since?: string;
}

export interface HaGetLogsOutput {
  entries: HaLogEntry[];
  summary: {
    errors: number;
    warnings: number;
  };
}

// Documentation types
export interface DocsSearchInput {
  query: string;
  section?: "core" | "frontend" | "architecture" | "api";
  limit?: number;
}

export interface DocsSearchResult {
  title: string;
  url: string;
  snippet: string;
  relevance: number;
}

export interface DocsSearchOutput {
  results: DocsSearchResult[];
}

export interface DocsFetchInput {
  path: string;
}

export interface DocsFetchOutput {
  title: string;
  content: string;
  last_updated: string;
  related: string[];
}

// Validation types
export interface ValidationError {
  field: string;
  message: string;
  severity: "error" | "warning";
}

export interface ValidateManifestInput {
  path: string;
  mode?: "core" | "hacs";
}

export interface ValidateManifestOutput {
  valid: boolean;
  errors: ValidationError[];
  warnings: ValidationError[];
}

export interface ValidateStringsInput {
  path: string;
}

export interface ValidateStringsOutput {
  valid: boolean;
  missing_steps: string[];
  orphaned_steps: string[];
  missing_errors: string[];
  missing_data_descriptions: string[];
}

export interface PatternIssue {
  file: string;
  line: number;
  pattern: string;
  message: string;
  severity: "error" | "warning";
  fix?: string;
}

export interface CheckPatternsInput {
  path: string;
}

export interface CheckPatternsOutput {
  issues: PatternIssue[];
  summary: {
    errors: number;
    warnings: number;
  };
}
