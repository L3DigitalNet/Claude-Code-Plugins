/**
 * A structured command ready for execution (Section 4).
 * Tool modules never build raw command strings — they produce Command objects.
 */
export interface Command {
  readonly argv: string[];
  readonly env?: Record<string, string>;
  readonly stdin?: string;
}
