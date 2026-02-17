/**
 * docs_search tool - Search Home Assistant developer documentation
 */

import { DocsIndex } from "../docs-index.js";
import type { DocsSearchInput, DocsSearchOutput } from "../types.js";

export async function handleDocsSearch(
  docsIndex: DocsIndex,
  input: DocsSearchInput
): Promise<DocsSearchOutput> {
  const results = docsIndex.search(input.query, {
    section: input.section,
    limit: input.limit || 5,
  });

  return {
    results,
  };
}
