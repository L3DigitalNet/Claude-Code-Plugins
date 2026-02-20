import { build } from 'esbuild';

// CJS dependencies (yaml, zod) use require() internally. When bundled into ESM,
// esbuild's __require shim can't resolve Node built-ins. This banner creates a
// real require function so CJS code works inside the ESM bundle.
const cjsShim = `
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
`;

await build({
  entryPoints: ['src/index.ts'],
  bundle: true,
  platform: 'node',
  target: 'node20',
  format: 'esm',
  outfile: 'dist/index.js',
  sourcemap: true,
  banner: { js: cjsShim },
});
