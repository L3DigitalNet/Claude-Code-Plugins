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
    related: page.related,
  };
}
