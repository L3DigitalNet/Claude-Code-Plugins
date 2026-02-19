// src/testing/utils.ts
export function slugify(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
}
