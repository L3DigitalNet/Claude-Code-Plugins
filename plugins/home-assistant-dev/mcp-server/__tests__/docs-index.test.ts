/**
 * Tests for DocsIndex
 */

import { DocsIndex } from '../src/docs-index.js';
import type { DocsSearchResult } from '../src/types.js';

describe('DocsIndex', () => {
  const defaultCacheConfig = {
    docsTtlHours: 24,
    statesTtlSeconds: 30,
  };

  let index: DocsIndex;

  beforeEach(() => {
    index = new DocsIndex(defaultCacheConfig);
  });

  describe('search', () => {
    it('should find DataUpdateCoordinator documentation', () => {
      const results = index.search('DataUpdateCoordinator');

      expect(results.length).toBeGreaterThan(0);
      expect(
        results.some(
          (r) =>
            r.title.toLowerCase().includes('coordinator') ||
            r.title.toLowerCase().includes('dataupdatecoordinator') ||
            r.title.toLowerCase().includes('fetching')
        )
      ).toBe(true);
    });

    it('should find config flow documentation', () => {
      const results = index.search('config flow reauth');

      expect(results.length).toBeGreaterThan(0);
      expect(
        results.some(
          (r) =>
            r.title.toLowerCase().includes('config') ||
            r.snippet.toLowerCase().includes('config flow') ||
            r.snippet.toLowerCase().includes('reauth')
        )
      ).toBe(true);
    });

    it('should return results with correct shape', () => {
      const results = index.search('integration');

      expect(results.length).toBeGreaterThan(0);

      for (const result of results) {
        expect(result).toHaveProperty('title');
        expect(result).toHaveProperty('url');
        expect(result).toHaveProperty('snippet');
        expect(result).toHaveProperty('relevance');

        expect(typeof result.title).toBe('string');
        expect(typeof result.url).toBe('string');
        expect(typeof result.snippet).toBe('string');
        expect(typeof result.relevance).toBe('number');

        expect(result.title.length).toBeGreaterThan(0);
        expect(result.url).toMatch(/^https:\/\//);
        expect(result.relevance).toBeGreaterThan(0);
      }
    });

    it('should limit results', () => {
      const results = index.search('integration', { limit: 2 });

      expect(results.length).toBeLessThanOrEqual(2);
    });

    it('should filter by section', () => {
      const results = index.search('integration', { section: 'core' });

      expect(results.length).toBeGreaterThan(0);
      for (const result of results) {
        expect(result.url).toContain('developers.home-assistant.io');
      }
    });

    it('should return empty for nonsense query', () => {
      const results = index.search('xyzzyfoobarbaz123');

      expect(results).toHaveLength(0);
    });
  });

  describe('fetchPage', () => {
    it('should fetch known page', async () => {
      const page = await index.fetchPage('core/integration-quality-scale');

      expect(page).not.toBeNull();
      expect(page!.title).toBe('Integration Quality Scale');
      expect(typeof page!.content).toBe('string');
      expect(page!.content.length).toBeGreaterThan(0);
      expect(typeof page!.lastUpdated).toBe('string');
    });

    it('should return null for unknown page', async () => {
      const page = await index.fetchPage('nonexistent/page');

      expect(page).toBeNull();
    });

    it('should return related pages', async () => {
      const page = await index.fetchPage('core/integration-quality-scale');

      expect(page).not.toBeNull();
      expect(Array.isArray(page!.related)).toBe(true);
      expect(page!.related.length).toBeGreaterThan(0);

      // Related pages should not include the page itself
      expect(page!.related).not.toContain('core/integration-quality-scale');
    });
  });
});
