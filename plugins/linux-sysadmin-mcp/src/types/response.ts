/** Error categories (Section 7.2). */
export type ErrorCategory =
  | "privilege"
  | "not_found"
  | "dependency"
  | "resource"
  | "lock"
  | "network"
  | "timeout"
  | "validation"
  | "state";

/** Base fields present in every response (Section 6 intro). */
export interface ResponseBase {
  status: "success" | "error" | "blocked" | "confirmation_required";
  tool: string;
  target_host: string;
  duration_ms: number;
  command_executed: string | null;
}

/** Successful response with tool-specific data. */
export interface SuccessResponse extends ResponseBase {
  status: "success";
  data: Record<string, unknown>;
  // Optional fields for list-returning tools
  total?: number;
  returned?: number;
  truncated?: boolean;
  filter?: string | null;
  // Analysis tools
  summary?: string;
  severity?: "info" | "warning" | "high" | "critical";
  // Documentation trigger
  documentation_action?: DocumentationAction;
  // Dry-run indicator
  dry_run?: boolean;
  // Remote session
  connection_restored?: boolean;
  connection_downtime_seconds?: number;
}

/** Error response (Section 7.2). */
export interface ErrorResponse extends ResponseBase {
  status: "error";
  error_code: string;
  error_category: ErrorCategory;
  message: string;
  transient: boolean;
  remediation: string[];
  // Delegated errors (Section 8.6)
  source?: string;
  original_error?: string;
}

/**
 * Blocked response for resource lock contention (Section 7.3).
 * Emitted when a package manager lock or similar resource lock is detected.
 * Distinct from ErrorResponse so Claude can distinguish "safety gate blocked"
 * from "operation blocked by OS resource lock".
 */
export interface BlockedResponse extends ResponseBase {
  status: "blocked";
  error_code: string;
  error_category: "lock";
  message: string;
  remediation: string[];
}

/** Confirmation required response (Section 7.4). */
export interface ConfirmationResponse extends ResponseBase {
  status: "confirmation_required";
  risk_level: string;
  dry_run_available: boolean;
  preview: {
    command: string;
    description: string;
    warnings: string[];
    affected_services?: string[];
    escalation_reason?: string;
  };
}

export type ToolResponse = SuccessResponse | ErrorResponse | BlockedResponse | ConfirmationResponse;

/** Documentation action suggested after state-changing ops (Section 6.13.3). */
export interface DocumentationAction {
  type: string;
  service?: string;
  suggested_actions: string[];
}
