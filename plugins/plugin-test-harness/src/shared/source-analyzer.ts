// src/shared/source-analyzer.ts
import fs from 'fs/promises';
import path from 'path';

export interface ToolSchema {
  name: string;
  description?: string;
  inputSchema?: {
    type: string;
    properties?: Record<string, { type: string; description?: string; enum?: unknown[]; minItems?: number; items?: Record<string, unknown> }>;
    required?: string[];
  };
}

export async function readToolSchemasFromSource(pluginPath: string): Promise<ToolSchema[]> {
  // Read .pth-tools-cache.json if present (populated by Claude after tools/list)
  const cachePath = path.join(pluginPath, '.pth-tools-cache.json');
  let raw: string;
  try {
    raw = await fs.readFile(cachePath, 'utf-8');
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw err;
  }
  return JSON.parse(raw) as ToolSchema[];
}

export async function writeToolSchemasCache(pluginPath: string, schemas: ToolSchema[]): Promise<void> {
  const cachePath = path.join(pluginPath, '.pth-tools-cache.json');
  await fs.writeFile(cachePath, JSON.stringify(schemas, null, 2), 'utf-8');
}
