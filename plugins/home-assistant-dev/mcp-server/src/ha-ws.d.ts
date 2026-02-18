/**
 * Type declarations for home-assistant-js-websocket
 *
 * This library does not ship its own type declarations.
 */

declare module "home-assistant-js-websocket" {
  export interface HassEntity {
    entity_id: string;
    state: string;
    attributes: Record<string, unknown>;
    last_changed: string;
    last_updated: string;
    context: {
      id: string;
      parent_id: string | null;
      user_id: string | null;
    };
  }

  export interface HassEntities {
    [entityId: string]: HassEntity;
  }

  export interface HassServiceField {
    name?: string;
    description?: string;
    required?: boolean;
    example?: unknown;
    selector?: Record<string, unknown>;
  }

  export interface HassServiceData {
    name?: string;
    description?: string;
    fields: Record<string, HassServiceField>;
    target?: {
      entity?: { domain?: string[] };
      device?: { integration?: string[] };
      area?: Record<string, unknown>;
    };
  }

  export interface HassServices {
    [domain: string]: {
      [service: string]: HassServiceData;
    };
  }

  export interface Auth {
    wsUrl: string;
    accessToken: string;
    expired: boolean;
  }

  export interface Connection {
    close(): void;
    sendMessagePromise<T>(message: Record<string, unknown>): Promise<T>;
  }

  export function createLongLivedTokenAuth(wsUrl: string, token: string): Auth;

  export function createConnection(options: { auth: Auth }): Promise<Connection>;

  export function getStates(connection: Connection): Promise<HassEntity[]>;

  export function getServices(connection: Connection): Promise<HassServices>;

  export function callService(
    connection: Connection,
    domain: string,
    service: string,
    data?: Record<string, unknown>
  ): Promise<unknown>;

  export function subscribeEntities(
    connection: Connection,
    callback: (entities: HassEntities) => void
  ): Promise<() => void>;
}
