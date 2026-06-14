/**
 * Home Assistant WebSocket Client
 *
 * Handles connection to Home Assistant via WebSocket API.
 * Provides methods for querying states, services, devices, and logs.
 */

import {
  createConnection,
  createLongLivedTokenAuth,
  getStates,
  getServices,
  callService,
  subscribeEntities,
  Connection,
  HassEntities,
  HassServices,
} from "home-assistant-js-websocket";

import type {
  HaState,
  HaService,
  HaServiceField,
  HaDevice,
  HaLogEntry,
  HaConnectOutput,
  ServerConfig,
} from "./types.js";

export class HaClient {
  private connection: Connection | null = null;
  private config: ServerConfig;
  private connectionInfo: HaConnectOutput | null = null;
  private statesCache: Map<string, HaState> = new Map();
  private statesCacheTime: number = 0;
  private unsubscribe: (() => void) | null = null;
  private servicesCache: HaService[] | null = null;
  private servicesCacheTime: number = 0;
  // Registry caches for area lookups (getEntitiesInArea). Both registries are fetched
  // together per area filter; cache them with the states TTL so a dev-loop's repeated
  // area queries reuse one WS round-trip instead of re-dumping both registries each call.
  private entityRegistryCache: Array<{
    entity_id: string;
    area_id: string | null;
    device_id: string | null;
  }> | null = null;
  private deviceRegistryCache: Array<{ id: string; area_id: string | null }> | null = null;
  private registryCacheTime: number = 0;

  constructor(config: ServerConfig) {
    this.config = config;
  }

  /**
   * Connect to Home Assistant
   */
  async connect(
    url: string,
    token: string,
    verifySsl?: boolean
  ): Promise<HaConnectOutput> {
    // Normalize URL - keep as http(s):// for the HA WS library
    // The library converts to ws:// internally
    const hassUrl = url.replace(/\/$/, "");

    const auth = createLongLivedTokenAuth(hassUrl, token);

    // home-assistant-js-websocket calls the global `WebSocket`, which Node only
    // exposes as a stable global from v21+, and the native global cannot relax
    // TLS verification. Always back it with `ws` (works on the Node 18/20 floor);
    // when verifySsl is false, use a subclass that passes rejectUnauthorized:false
    // so self-signed-cert HA instances over https are reachable.
    const verify = verifySsl ?? this.config.homeAssistant.verifySsl;
    const { WebSocket: WsWebSocket } = await import("ws");
    globalThis.WebSocket = (
      verify
        ? WsWebSocket
        : class extends WsWebSocket {
            constructor(address: string | URL, protocols?: string | string[]) {
              super(address, protocols, { rejectUnauthorized: false });
            }
          }
    ) as unknown as typeof globalThis.WebSocket;

    try {
      this.connection = await createConnection({ auth });

      // Invalidate cached registries/services from any prior connection — a reconnect
      // may target a different HA instance, and stale entries would misreport area
      // membership or available services.
      this.servicesCache = null;
      this.servicesCacheTime = 0;
      this.entityRegistryCache = null;
      this.deviceRegistryCache = null;
      this.registryCacheTime = 0;

      // Get HA config for connection info
      const haConfig = await this.connection.sendMessagePromise<{
        version: string;
        location_name: string;
        components: string[];
      }>({ type: "get_config" });

      // sendMessagePromise casts the response to the generic with no runtime check;
      // minimally validate the get_config shape before trusting it for connection info.
      if (
        !haConfig ||
        typeof haConfig.version !== "string" ||
        !Array.isArray(haConfig.components)
      ) {
        throw new Error("Unexpected response from Home Assistant get_config");
      }

      this.connectionInfo = {
        connected: true,
        version: haConfig.version,
        location: haConfig.location_name,
        components: haConfig.components,
      };

      // Subscribe to state changes for caching; keep the unsubscribe handle so the
      // listener can be detached on disconnect.
      this.unsubscribe = subscribeEntities(this.connection, (entities: HassEntities) => {
        this.updateStatesCache(entities);
      });

      return this.connectionInfo;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to connect to Home Assistant: ${message}`, {
        cause: error,
      });
    }
  }

  /**
   * Disconnect from Home Assistant
   */
  async disconnect(): Promise<void> {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
    if (this.connection) {
      this.connection.close();
      this.connection = null;
      this.connectionInfo = null;
    }
  }

  /**
   * Check if connected
   */
  isConnected(): boolean {
    return this.connection !== null && this.connectionInfo !== null;
  }

  /**
   * Get connection info
   */
  getConnectionInfo(): HaConnectOutput {
    if (!this.connectionInfo) {
      return {
        connected: false,
        version: "",
        location: "",
        components: [],
      };
    }
    return this.connectionInfo;
  }

  /**
   * Update states cache from subscription
   */
  private updateStatesCache(entities: HassEntities): void {
    this.statesCache.clear();
    for (const [entityId, state] of Object.entries(entities)) {
      this.statesCache.set(entityId, {
        entity_id: entityId,
        state: state.state,
        attributes: state.attributes,
        last_changed: state.last_changed,
        last_updated: state.last_updated,
        context: state.context,
      });
    }
    this.statesCacheTime = Date.now();
  }

  /**
   * Get entity states
   */
  async getStates(filters?: {
    domain?: string;
    entityId?: string;
    area?: string;
  }): Promise<HaState[]> {
    if (!this.connection) {
      throw new Error("Not connected to Home Assistant");
    }

    // Use cache if fresh enough
    const cacheAge = (Date.now() - this.statesCacheTime) / 1000;
    let states: HaState[];

    if (cacheAge < this.config.cache.statesTtlSeconds && this.statesCache.size > 0) {
      states = Array.from(this.statesCache.values());
    } else {
      // Fetch fresh states
      const hassStates = await getStates(this.connection);
      states = hassStates.map((s) => ({
        entity_id: s.entity_id,
        state: s.state,
        attributes: s.attributes,
        last_changed: s.last_changed,
        last_updated: s.last_updated,
        context: s.context,
      }));
    }

    // Apply filters
    if (filters?.entityId) {
      states = states.filter((s) => s.entity_id === filters.entityId);
    } else if (filters?.domain) {
      states = states.filter((s) => s.entity_id.startsWith(`${filters.domain}.`));
    }

    // Area filtering requires device/entity registry lookup
    if (filters?.area) {
      const areaEntities = await this.getEntitiesInArea(filters.area);
      const areaEntityIds = new Set(areaEntities);
      states = states.filter((s) => areaEntityIds.has(s.entity_id));
    }

    return states;
  }

  /**
   * Get entities in an area
   */
  private async getEntitiesInArea(areaId: string): Promise<string[]> {
    if (!this.connection) {
      return [];
    }

    try {
      // Reuse cached registries within the TTL; otherwise fetch both and cache them.
      const cacheAge = (Date.now() - this.registryCacheTime) / 1000;
      let entityRegistry = this.entityRegistryCache;
      let deviceRegistry = this.deviceRegistryCache;

      if (!entityRegistry || !deviceRegistry || cacheAge >= this.config.cache.statesTtlSeconds) {
        // Get entity registry
        entityRegistry = await this.connection.sendMessagePromise<
          Array<{ entity_id: string; area_id: string | null; device_id: string | null }>
        >({ type: "config/entity_registry/list" });

        // Get device registry for devices in area
        deviceRegistry = await this.connection.sendMessagePromise<
          Array<{ id: string; area_id: string | null }>
        >({ type: "config/device_registry/list" });

        this.entityRegistryCache = entityRegistry;
        this.deviceRegistryCache = deviceRegistry;
        this.registryCacheTime = Date.now();
      }

      const devicesInArea = new Set(
        deviceRegistry.filter((d) => d.area_id === areaId).map((d) => d.id)
      );

      // Find entities directly in area or via device
      return entityRegistry
        .filter(
          (e) => e.area_id === areaId || (e.device_id && devicesInArea.has(e.device_id))
        )
        .map((e) => e.entity_id);
    } catch (error) {
      // Do not fail open to an empty list — a registry error would otherwise look like
      // "no entities in that area" and silently drop a real area filter.
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`Area lookup failed for '${areaId}': ${message}`, { cause: error });
    }
  }

  /**
   * Get available services
   */
  async getServices(domain?: string): Promise<HaService[]> {
    if (!this.connection) {
      throw new Error("Not connected to Home Assistant");
    }

    // Cache the full catalog with the same TTL as states — it rarely changes, and
    // validateServiceCall (every ha_call_service, including dry-runs) reads it.
    const cacheAge = (Date.now() - this.servicesCacheTime) / 1000;
    let allServices: HaService[];

    if (this.servicesCache && cacheAge < this.config.cache.statesTtlSeconds) {
      allServices = this.servicesCache;
    } else {
      const hassServices: HassServices = await getServices(this.connection);
      allServices = [];

      for (const [serviceDomain, domainServices] of Object.entries(hassServices)) {
        for (const [serviceName, serviceData] of Object.entries(domainServices)) {
          const fields: Record<string, HaServiceField> = {};
          for (const [fieldName, fieldData] of Object.entries(serviceData.fields || {})) {
            fields[fieldName] = {
              name: fieldData.name || fieldName,
              description: fieldData.description || "",
              required: fieldData.required || false,
              example: fieldData.example,
              selector: fieldData.selector,
            };
          }

          allServices.push({
            domain: serviceDomain,
            service: serviceName,
            name: serviceData.name || serviceName,
            description: serviceData.description || "",
            fields,
            target: serviceData.target,
          });
        }
      }

      this.servicesCache = allServices;
      this.servicesCacheTime = Date.now();
    }

    return domain ? allServices.filter((s) => s.domain === domain) : allServices;
  }

  /**
   * Call a service
   */
  async callService(
    domain: string,
    service: string,
    data?: Record<string, unknown>,
    target?: {
      entity_id?: string | string[];
      device_id?: string | string[];
      area_id?: string | string[];
    }
  ): Promise<unknown> {
    if (!this.connection) {
      throw new Error("Not connected to Home Assistant");
    }

    // The home-assistant-js-websocket callService helper has no separate `target`
    // argument, so entity_id/device_id/area_id are folded into the service data. HA
    // accepts entity_id this way; device_id/area_id are forwarded the same way and rely
    // on HA resolving them from the service data.
    const serviceData = {
      ...data,
      ...target,
    };

    return callService(this.connection, domain, service, serviceData);
  }

  /**
   * Get devices from device registry
   */
  async getDevices(filters?: {
    manufacturer?: string;
    model?: string;
    integration?: string;
  }): Promise<HaDevice[]> {
    if (!this.connection) {
      throw new Error("Not connected to Home Assistant");
    }

    const deviceRegistry = await this.connection.sendMessagePromise<
      Array<{
        id: string;
        name: string;
        name_by_user: string | null;
        manufacturer: string | null;
        model: string | null;
        sw_version: string | null;
        hw_version: string | null;
        via_device_id: string | null;
        area_id: string | null;
        config_entries: string[];
        identifiers: Array<[string, string]>;
      }>
    >({ type: "config/device_registry/list" });

    let devices: HaDevice[] = deviceRegistry.map((d) => ({
      id: d.id,
      name: d.name,
      name_by_user: d.name_by_user,
      manufacturer: d.manufacturer,
      model: d.model,
      sw_version: d.sw_version,
      hw_version: d.hw_version,
      via_device_id: d.via_device_id,
      area_id: d.area_id,
      config_entries: d.config_entries,
      identifiers: d.identifiers,
    }));

    // Apply filters
    if (filters?.manufacturer) {
      const mfr = filters.manufacturer.toLowerCase();
      devices = devices.filter(
        (d) => d.manufacturer?.toLowerCase().includes(mfr)
      );
    }

    if (filters?.model) {
      const model = filters.model.toLowerCase();
      devices = devices.filter((d) => d.model?.toLowerCase().includes(model));
    }

    if (filters?.integration) {
      try {
        // config_entries/get is admin-only; on a non-admin long-lived token it rejects.
        const configEntries = await this.connection.sendMessagePromise<
          Array<{ entry_id: string; domain: string }>
        >({ type: "config_entries/get" });

        const integrationEntries = new Set(
          configEntries
            .filter((e) => e.domain === filters.integration)
            .map((e) => e.entry_id)
        );

        devices = devices.filter((d) =>
          d.config_entries.some((e) => integrationEntries.has(e))
        );
      } catch (error) {
        // Skip the integration filter rather than failing the whole getDevices call —
        // config_entries/get requires an admin token, which the connection may lack.
        const message = error instanceof Error ? error.message : String(error);
        console.error(
          `ha_get_devices: integration filter skipped (config_entries/get failed, needs admin token): ${message}`
        );
      }
    }

    return devices;
  }

  /**
   * Get logs from Home Assistant
   */
  async getLogs(filters?: {
    domain?: string;
    level?: "DEBUG" | "INFO" | "WARNING" | "ERROR";
    lines?: number;
    since?: string;
  }): Promise<HaLogEntry[]> {
    if (!this.connection) {
      throw new Error("Not connected to Home Assistant");
    }

    // Fetch logs via system_log
    const logEntries = await this.connection.sendMessagePromise<
      Array<{
        timestamp: number;
        level: string;
        source: [string, number];
        message: string;
        exception: string;
        count: number;
        first_occurred: number;
      }>
    >({ type: "system_log/list" });

    if (!Array.isArray(logEntries)) {
      return [];
    }

    const levelPriority: Record<string, number> = {
      DEBUG: 0,
      INFO: 1,
      WARNING: 2,
      ERROR: 3,
      CRITICAL: 4,
    };

    const minLevel = filters?.level ? levelPriority[filters.level] : 0;
    // Validate `since`: an unparseable timestamp must not silently disable the filter
    // (NaN comparisons are always false, which would keep everything).
    let sinceTimestamp = 0;
    if (filters?.since) {
      const parsed = Date.parse(filters.since);
      if (Number.isNaN(parsed)) {
        throw new Error(`Invalid 'since' timestamp: ${filters.since}`);
      }
      // system_log/list reports `timestamp` as epoch seconds.
      sinceTimestamp = parsed / 1000;
    }

    let logs: HaLogEntry[] = logEntries
      .filter((entry) => {
        // Level filter — coerce an unknown level to INFO instead of keeping it blindly
        // (an undefined priority would slip past a numeric `< minLevel` comparison).
        const entryPriority = levelPriority[entry.level] ?? levelPriority.INFO;
        if (entryPriority < minLevel) {
          return false;
        }

        // Time filter (epoch seconds, see above)
        if (entry.timestamp < sinceTimestamp) {
          return false;
        }

        // Domain filter
        if (filters?.domain) {
          const source = entry.source?.[0] ?? "";
          if (!source.includes(filters.domain)) {
            return false;
          }
        }

        return true;
      })
      .map((entry) => ({
        timestamp: new Date(entry.timestamp * 1000).toISOString(),
        level: entry.level as HaLogEntry["level"],
        source: entry.source?.[0] ?? "unknown",
        message: entry.message,
      }));

    // Limit lines
    const maxLines = filters?.lines || 100;
    if (logs.length > maxLines) {
      logs = logs.slice(-maxLines);
    }

    return logs;
  }

  /**
   * Validate a service call without executing
   */
  async validateServiceCall(
    domain: string,
    service: string,
    data?: Record<string, unknown>,
    target?: {
      entity_id?: string | string[];
      device_id?: string | string[];
      area_id?: string | string[];
    }
  ): Promise<{ valid: boolean; errors: string[] }> {
    const errors: string[] = [];

    // Check if service exists
    const services = await this.getServices(domain);
    const serviceInfo = services.find((s) => s.service === service);

    if (!serviceInfo) {
      errors.push(`Service ${domain}.${service} not found`);
      return { valid: false, errors };
    }

    // Check required fields by key presence, not truthiness — a supplied 0/false/""
    // is a valid value, not a missing field.
    for (const [fieldName, fieldInfo] of Object.entries(serviceInfo.fields)) {
      if (fieldInfo.required && !(fieldName in (data ?? {}))) {
        errors.push(`Required field '${fieldName}' is missing`);
      }
    }

    // Check if target is required
    if (serviceInfo.target && !target?.entity_id && !target?.device_id && !target?.area_id) {
      errors.push("Service requires a target (entity_id, device_id, or area_id)");
    }

    // Validate target entities exist
    if (target?.entity_id) {
      const entityIds = Array.isArray(target.entity_id)
        ? target.entity_id
        : [target.entity_id];

      const states = await this.getStates();
      const existingIds = new Set(states.map((s) => s.entity_id));

      for (const entityId of entityIds) {
        if (!existingIds.has(entityId)) {
          errors.push(`Entity ${entityId} not found`);
        }
      }
    }

    return { valid: errors.length === 0, errors };
  }
}
