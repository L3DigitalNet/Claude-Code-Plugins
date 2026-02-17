/**
 * Documentation Index for Home Assistant Developer Docs
 *
 * Provides full-text search over pre-indexed documentation.
 * Caches fetched pages for offline access.
 */

import MiniSearch from "minisearch";
import { readFile, writeFile, mkdir } from "fs/promises";
import { homedir } from "os";
import { join } from "path";
import type { ServerConfig, DocsSearchResult } from "./types.js";

interface DocPage {
  id: string;
  path: string;
  title: string;
  content: string;
  section: string;
  lastUpdated: string;
}

// Pre-indexed documentation entries
// In production, this would be fetched/updated periodically
const DOCS_INDEX: DocPage[] = [
  {
    id: "integration-quality-scale",
    path: "core/integration-quality-scale",
    title: "Integration Quality Scale",
    section: "core",
    lastUpdated: "2025-02-01",
    content: `The Integration Quality Scale is a framework for measuring the quality of Home Assistant integrations. 
    It has four tiers: Bronze, Silver, Gold, and Platinum. Each tier has specific requirements that integrations must meet.
    Bronze requires config flow, unique IDs, and basic tests. Silver adds error handling and reauth.
    Gold requires diagnostics, discovery, and translations. Platinum needs async dependencies and strict typing.`,
  },
  {
    id: "creating-component",
    path: "creating_component_index",
    title: "Creating an Integration",
    section: "core",
    lastUpdated: "2025-02-01",
    content: `Guide to creating a Home Assistant integration from scratch. Covers manifest.json, __init__.py,
    config flow, entity platforms, and services. New integrations must use config flow - YAML only is deprecated.
    Use entry.runtime_data instead of hass.data[DOMAIN] for storing coordinator instances.`,
  },
  {
    id: "config-entries-flow",
    path: "config_entries_config_flow_handler",
    title: "Config Flow",
    section: "core",
    lastUpdated: "2025-02-01",
    content: `Config flows provide UI-based configuration for integrations. Implement ConfigFlow with async_step_user
    for initial setup. Use async_set_unique_id to prevent duplicates. Implement async_step_reauth for credential refresh.
    Options flow allows changing settings after setup. Store connection info in entry.data, preferences in entry.options.`,
  },
  {
    id: "data-update-coordinator",
    path: "integration_fetching_data",
    title: "DataUpdateCoordinator",
    section: "core",
    lastUpdated: "2025-02-01",
    content: `DataUpdateCoordinator manages data fetching and caching for integrations. It handles rate limiting,
    error handling, and notifies entities of updates. Use _async_setup for one-time initialization (added in 2024.8).
    Use _async_update_data for periodic fetches. Raise UpdateFailed for recoverable errors, ConfigEntryAuthFailed for reauth.`,
  },
  {
    id: "entity-platforms",
    path: "core/entity",
    title: "Entity Platforms",
    section: "core",
    lastUpdated: "2025-02-01",
    content: `Entities represent devices and services in Home Assistant. Each platform (sensor, switch, light, etc.)
    has specific requirements. Use _attr_has_entity_name = True for proper naming. Set unique_id for entity registry.
    Use EntityDescription for declarative entity definitions. Implement device_info for device grouping.`,
  },
  {
    id: "services",
    path: "core/platform/service",
    title: "Service Actions",
    section: "core",
    lastUpdated: "2025-02-01",
    content: `Services allow automations and users to interact with integrations. Register services in async_setup,
    not async_setup_entry. Define service schemas using voluptuous. Handle errors by raising HomeAssistantError
    or ServiceValidationError. Document services in services.yaml for the UI.`,
  },
  {
    id: "diagnostics",
    path: "core/integration-diagnostics",
    title: "Diagnostics",
    section: "core",
    lastUpdated: "2025-02-01",
    content: `Diagnostics provide debug information for troubleshooting. Implement async_get_config_entry_diagnostics
    in diagnostics.py. Use async_redact_data to protect sensitive information like passwords, tokens, and serial numbers.
    Include coordinator data, device info, and relevant state. Required for Gold tier.`,
  },
  {
    id: "testing",
    path: "development_testing",
    title: "Testing Integrations",
    section: "core",
    lastUpdated: "2025-02-01",
    content: `Testing is required for Bronze tier. Use pytest with pytest-homeassistant-custom-component.
    Test config flow for success, connection failure, and auth failure. Use MockConfigEntry for setup tests.
    Mock the client library, not the coordinator. Call await hass.async_block_till_done() after setup.`,
  },
  {
    id: "manifest",
    path: "creating_integration_manifest",
    title: "Integration Manifest",
    section: "core",
    lastUpdated: "2025-02-01",
    content: `manifest.json defines integration metadata. Required fields: domain, name, codeowners, documentation,
    integration_type, iot_class. For custom integrations add version and issue_tracker. integration_type can be
    hub, device, service, or system. iot_class describes how the integration communicates: local_polling, local_push,
    cloud_polling, cloud_push, or calculated.`,
  },
  {
    id: "runtime-data",
    path: "core/runtime-data",
    title: "Runtime Data Pattern",
    section: "core",
    lastUpdated: "2025-02-01",
    content: `The runtime_data pattern replaces hass.data[DOMAIN] for storing coordinator instances.
    Define a type alias: type MyConfigEntry = ConfigEntry[MyCoordinator]. In async_setup_entry, assign
    entry.runtime_data = coordinator. Access in platforms via entry.runtime_data. Cleanup is automatic on unload.`,
  },
];

const CACHE_DIR = join(homedir(), ".cache", "ha-dev-mcp", "docs");

export class DocsIndex {
  private searchIndex: MiniSearch<DocPage>;
  private docs: Map<string, DocPage> = new Map();
  private config: ServerConfig["cache"];

  constructor(config: ServerConfig["cache"]) {
    this.config = config;

    // Initialize search index
    this.searchIndex = new MiniSearch({
      fields: ["title", "content"],
      storeFields: ["path", "title", "section", "lastUpdated"],
      searchOptions: {
        boost: { title: 2 },
        fuzzy: 0.2,
        prefix: true,
      },
    });

    // Index pre-built docs
    for (const doc of DOCS_INDEX) {
      this.docs.set(doc.path, doc);
    }
    this.searchIndex.addAll(DOCS_INDEX);
  }

  /**
   * Search documentation
   */
  search(
    query: string,
    options?: { section?: string; limit?: number }
  ): DocsSearchResult[] {
    const limit = options?.limit || 5;

    let results = this.searchIndex.search(query);

    // Filter by section if specified
    if (options?.section) {
      results = results.filter((r) => r.section === options.section);
    }

    // Limit results
    results = results.slice(0, limit);

    return results.map((r) => ({
      title: r.title as string,
      url: `https://developers.home-assistant.io/docs/${r.path}`,
      snippet: this.getSnippet(r.id as string, query),
      relevance: r.score,
    }));
  }

  /**
   * Get a snippet around the matched query
   */
  private getSnippet(docId: string, query: string): string {
    const doc = this.docs.get(
      DOCS_INDEX.find((d) => d.id === docId)?.path || ""
    );
    if (!doc) return "";

    const content = doc.content;
    const queryLower = query.toLowerCase();
    const contentLower = content.toLowerCase();

    const matchIndex = contentLower.indexOf(queryLower);
    if (matchIndex === -1) {
      // Return first 200 chars if no direct match
      return content.slice(0, 200) + "...";
    }

    // Get context around match
    const start = Math.max(0, matchIndex - 50);
    const end = Math.min(content.length, matchIndex + query.length + 150);

    let snippet = content.slice(start, end);
    if (start > 0) snippet = "..." + snippet;
    if (end < content.length) snippet = snippet + "...";

    return snippet;
  }

  /**
   * Fetch a specific documentation page
   */
  async fetchPage(path: string): Promise<{
    title: string;
    content: string;
    lastUpdated: string;
    related: string[];
  } | null> {
    // Check local index first
    const doc = this.docs.get(path);
    if (doc) {
      return {
        title: doc.title,
        content: doc.content,
        lastUpdated: doc.lastUpdated,
        related: this.getRelatedPages(path),
      };
    }

    // Check cache
    const cached = await this.loadFromCache(path);
    if (cached) {
      return cached;
    }

    // In production, fetch from developers.home-assistant.io
    // For now, return null for unknown pages
    return null;
  }

  /**
   * Get related documentation pages
   */
  private getRelatedPages(path: string): string[] {
    const doc = this.docs.get(path);
    if (!doc) return [];

    // Find pages in the same section
    const related: string[] = [];
    for (const [docPath, docPage] of this.docs) {
      if (docPath !== path && docPage.section === doc.section) {
        related.push(docPath);
      }
      if (related.length >= 5) break;
    }

    return related;
  }

  /**
   * Load page from cache
   */
  private async loadFromCache(path: string): Promise<{
    title: string;
    content: string;
    lastUpdated: string;
    related: string[];
  } | null> {
    try {
      const cachePath = join(CACHE_DIR, `${path.replace(/\//g, "_")}.json`);
      const content = await readFile(cachePath, "utf-8");
      const cached = JSON.parse(content);

      // Check if cache is still valid
      const cacheAge =
        (Date.now() - new Date(cached.cachedAt).getTime()) / (1000 * 60 * 60);
      if (cacheAge > this.config.docsTtlHours) {
        return null;
      }

      return cached.data;
    } catch {
      return null;
    }
  }

  /**
   * Save page to cache
   */
  private async saveToCache(
    path: string,
    data: { title: string; content: string; lastUpdated: string; related: string[] }
  ): Promise<void> {
    try {
      await mkdir(CACHE_DIR, { recursive: true });
      const cachePath = join(CACHE_DIR, `${path.replace(/\//g, "_")}.json`);
      await writeFile(
        cachePath,
        JSON.stringify({ cachedAt: new Date().toISOString(), data })
      );
    } catch {
      // Ignore cache write errors
    }
  }
}
