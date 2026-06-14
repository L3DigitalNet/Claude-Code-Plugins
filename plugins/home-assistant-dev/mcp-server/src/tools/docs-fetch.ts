/**
 * docs_fetch tool - Fetch specific documentation page
 */

import { DocsIndex } from "../docs-index.js";
import type { DocsFetchInput, DocsFetchOutput } from "../types.js";

export async function handleDocsFetch(
  docsIndex: DocsIndex,
  input: DocsFetchInput
): Promise<DocsFetchOutput> {
  const page = await docsIndex.fetchPage(input.path);

  if (!page) {
    throw new Error(
      `Documentation page not found: ${input.path}. ` +
        `Try searching with docs_search first.`
    );
  }

  return {
    title: page.title,
    content: page.content,
    last_updated: page.lastUpdated,
    // page.related is a list of internal index paths (e.g. "core/runtime-data").
    // Normalize to the same developers.home-assistant.io URL form that docs_search
    // emits so 'related' is consistent across tools. The trailing path segment after
    // /docs/ is exactly what docs_fetch's `path` input expects, so a consumer can
    // re-feed it directly.
    related: page.related.map(
      (relatedPath) => `https://developers.home-assistant.io/docs/${relatedPath}`
    ),
  };
}
