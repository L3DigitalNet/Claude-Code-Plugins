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

  constructor(config: ServerConfig) {
    this.config = config;
  }

  /**
   * Connect to Home Assistant
   */
  async connect(url: string, token: string): Promise<HaConnectOutput> {
    // Normalize URL
    const wsUrl = url
      .replace(/^http:\/\//, "ws://")
      .replace(/^https:\/\//, "wss://")
      .replace(/\/$/, "");

    const auth = createLongLivedTokenAuth(wsUrl, token);

    try {
      this.connection = await createConnection({ auth });

      // Get HA config for connection info
      const haConfig = await this.connection.sendMessagePromise<{
        version: string;
        location_name: string;
        components: string[];
      }>({ type: "get_config" });

      this.connectionInfo = {
        connected: true,
        version: haConfig.version,
        location: haConfig.location_name,
        components: haConfig.components,
      };

      // Subscribe to state changes for caching
      subscribeEntities(this.connection, (entities: HassEntities) => {
        this.updateStatesCache(entities);
      });

      return this.connectionInfo;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to connect to Home Assistant: ${message}`);
    }
  }

  /**
   * Disconnect from Home Assistant
   */
  async disconnect(): Promise<void> {
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
      // Get entity registry
      const entityRegistry = await this.connection.sendMessagePromise<
        Array<{ entity_id: string; area_id: string | null; device_id: string | null }>
      >({ type: "config/entity_registry/list" });

      // Get device registry for devices in area
      const deviceRegistry = await this.connection.sendMessagePromise<
        Array<{ id: string; area_id: string | null }>
      >({ type: "config/device_registry/list" });

      const devicesInArea = new Set(
        deviceRegistry.filter((d) => d.area_id === areaId).map((d) => d.id)
      );

      // Find entities directly in area or via device
      return entityRegistry
        .filter(
          (e) => e.area_id === areaId || (e.device_id && devicesInArea.has(e.device_id))
        )
        .map((e) => e.entity_id);
    } catch {
      return [];
    }
  }

  /**
   * Get available services
   */
  async getServices(domain?: string): Promise<HaService[]> {
    if (!this.connection) {
      throw new Error("Not connected to Home Assistant");
    }

    const hassServices: HassServices = await getServices(this.connection);
    const services: HaService[] = [];

    for (const [serviceDomain, domainServices] of Object.entries(hassServices)) {
      if (domain && serviceDomain !== domain) {
        continue;
      }

      for (const [serviceName, serviceData] of Object.entries(domainServices)) {
        services.push({
          domain: serviceDomain,
          service: serviceName,
          name: serviceData.name || serviceName,
          description: serviceData.description || "",
          fields: serviceData.fields || {},
          target: serviceData.target,
        });
      }
    }

    return services;
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
      // Get config entries to map integration domains
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

    const levelPriority: Record<string, number> = {
      DEBUG: 0,
      INFO: 1,
      WARNING: 2,
      ERROR: 3,
      CRITICAL: 4,
    };

    const minLevel = filters?.level ? levelPriority[filters.level] : 0;
    const sinceTimestamp = filters?.since ? new Date(filters.since).getTime() / 1000 : 0;

    let logs: HaLogEntry[] = logEntries
      .filter((entry) => {
        // Level filter
        if (levelPriority[entry.level] < minLevel) {
          return false;
        }

        // Time filter
        if (entry.timestamp < sinceTimestamp) {
          return false;
        }

        // Domain filter
        if (filters?.domain) {
          const source = entry.source[0];
          if (!source.includes(filters.domain)) {
            return false;
          }
        }

        return true;
      })
      .map((entry) => ({
        timestamp: new Date(entry.timestamp * 1000).toISOString(),
        level: entry.level as HaLogEntry["level"],
        source: entry.source[0],
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

    // Check required fields
    for (const [fieldName, fieldInfo] of Object.entries(serviceInfo.fields)) {
      if (fieldInfo.required && !data?.[fieldName]) {
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
