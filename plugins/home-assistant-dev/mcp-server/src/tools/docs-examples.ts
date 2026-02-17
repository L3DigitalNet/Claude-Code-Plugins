/**
 * docs_examples tool - Get code examples for common patterns
 */

interface ExampleInput {
  pattern: string;
  style?: "minimal" | "full";
}

interface ExampleOutput {
  pattern: string;
  description: string;
  code: string;
  files?: Array<{ path: string; content: string }>;
}

const EXAMPLES: Record<string, { minimal: ExampleOutput; full: ExampleOutput }> = {
  coordinator: {
    minimal: {
      pattern: "coordinator",
      description: "Minimal DataUpdateCoordinator implementation",
      code: `from homeassistant.helpers.update_coordinator import DataUpdateCoordinator, UpdateFailed

class MyCoordinator(DataUpdateCoordinator[dict]):
    async def _async_update_data(self) -> dict:
        try:
            return await self.client.async_get_data()
        except Exception as err:
            raise UpdateFailed(f"Error: {err}") from err`,
    },
    full: {
      pattern: "coordinator",
      description: "Full DataUpdateCoordinator with _async_setup and error handling",
      code: `"""DataUpdateCoordinator for My Integration."""
from __future__ import annotations

from datetime import timedelta
from typing import Any

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.exceptions import ConfigEntryAuthFailed
from homeassistant.helpers.update_coordinator import DataUpdateCoordinator, UpdateFailed

from .const import DOMAIN

class MyCoordinator(DataUpdateCoordinator[dict[str, Any]]):
    """Coordinator to manage data fetching."""

    config_entry: ConfigEntry

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        super().__init__(
            hass,
            logger,
            name=DOMAIN,
            update_interval=timedelta(seconds=30),
        )
        self.client = MyClient(entry.data["host"])

    async def _async_setup(self) -> None:
        """Set up the coordinator (runs once)."""
        self.device_info = await self.client.async_get_device_info()

    async def _async_update_data(self) -> dict[str, Any]:
        """Fetch data from device."""
        try:
            return await self.client.async_get_data()
        except AuthError as err:
            raise ConfigEntryAuthFailed("Invalid credentials") from err
        except ConnectionError as err:
            raise UpdateFailed(f"Connection failed: {err}") from err`,
    },
  },

  config_flow: {
    minimal: {
      pattern: "config_flow",
      description: "Minimal config flow with user step",
      code: `from homeassistant.config_entries import ConfigFlow, ConfigFlowResult

class MyConfigFlow(ConfigFlow, domain=DOMAIN):
    VERSION = 1

    async def async_step_user(self, user_input=None) -> ConfigFlowResult:
        if user_input is not None:
            return self.async_create_entry(title="My Device", data=user_input)
        return self.async_show_form(step_id="user", data_schema=SCHEMA)`,
    },
    full: {
      pattern: "config_flow",
      description: "Full config flow with validation, reauth, and options",
      code: `"""Config flow for My Integration."""
from __future__ import annotations

from typing import Any
import voluptuous as vol

from homeassistant.config_entries import ConfigFlow, ConfigFlowResult, OptionsFlow
from homeassistant.const import CONF_HOST, CONF_PASSWORD, CONF_USERNAME
from homeassistant.core import callback

from .const import DOMAIN

class MyConfigFlow(ConfigFlow, domain=DOMAIN):
    VERSION = 1

    async def async_step_user(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        errors = {}
        if user_input is not None:
            try:
                info = await self._validate(user_input)
            except CannotConnect:
                errors["base"] = "cannot_connect"
            except InvalidAuth:
                errors["base"] = "invalid_auth"
            else:
                await self.async_set_unique_id(info["serial"])
                self._abort_if_unique_id_configured()
                return self.async_create_entry(title=info["name"], data=user_input)

        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema({
                vol.Required(CONF_HOST): str,
                vol.Required(CONF_USERNAME): str,
                vol.Required(CONF_PASSWORD): str,
            }),
            errors=errors,
        )

    async def async_step_reauth(self, entry_data: dict) -> ConfigFlowResult:
        return await self.async_step_reauth_confirm()

    async def async_step_reauth_confirm(self, user_input=None) -> ConfigFlowResult:
        if user_input is not None:
            entry = self._get_reauth_entry()
            data = {**entry.data, **user_input}
            try:
                await self._validate(data)
            except (CannotConnect, InvalidAuth):
                return self.async_show_form(step_id="reauth_confirm", errors={"base": "invalid_auth"})
            return self.async_update_reload_and_abort(entry, data=data)
        return self.async_show_form(step_id="reauth_confirm")

    @staticmethod
    @callback
    def async_get_options_flow(entry):
        return MyOptionsFlow()

class MyOptionsFlow(OptionsFlow):
    async def async_step_init(self, user_input=None) -> ConfigFlowResult:
        if user_input is not None:
            return self.async_create_entry(data=user_input)
        return self.async_show_form(step_id="init", data_schema=OPTIONS_SCHEMA)`,
    },
  },

  sensor: {
    minimal: {
      pattern: "sensor",
      description: "Minimal sensor entity",
      code: `from homeassistant.components.sensor import SensorEntity

class MySensor(SensorEntity):
    _attr_has_entity_name = True
    _attr_name = "Temperature"

    def __init__(self, coordinator, device_id):
        self._attr_unique_id = f"{device_id}_temp"

    @property
    def native_value(self):
        return self.coordinator.data.get("temperature")`,
    },
    full: {
      pattern: "sensor",
      description: "Full sensor with EntityDescription and CoordinatorEntity",
      code: `"""Sensor platform for My Integration."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable

from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorEntityDescription,
    SensorStateClass,
)
from homeassistant.const import UnitOfTemperature
from homeassistant.helpers.update_coordinator import CoordinatorEntity

@dataclass(frozen=True, kw_only=True)
class MySensorDescription(SensorEntityDescription):
    value_fn: Callable[[dict[str, Any]], float | None]

SENSORS: tuple[MySensorDescription, ...] = (
    MySensorDescription(
        key="temperature",
        translation_key="temperature",
        device_class=SensorDeviceClass.TEMPERATURE,
        state_class=SensorStateClass.MEASUREMENT,
        native_unit_of_measurement=UnitOfTemperature.CELSIUS,
        value_fn=lambda data: data.get("temperature"),
    ),
)

async def async_setup_entry(hass, entry, async_add_entities):
    coordinator = entry.runtime_data
    async_add_entities(
        MySensor(coordinator, desc) for desc in SENSORS
    )

class MySensor(CoordinatorEntity, SensorEntity):
    entity_description: MySensorDescription
    _attr_has_entity_name = True

    def __init__(self, coordinator, description):
        super().__init__(coordinator)
        self.entity_description = description
        self._attr_unique_id = f"{coordinator.config_entry.entry_id}_{description.key}"

    @property
    def native_value(self):
        return self.entity_description.value_fn(self.coordinator.data)`,
    },
  },

  entity: {
    minimal: {
      pattern: "entity",
      description: "Minimal base entity class",
      code: `from homeassistant.helpers.entity import Entity

class MyEntity(Entity):
    _attr_has_entity_name = True

    def __init__(self, device_id):
        self._attr_unique_id = device_id`,
    },
    full: {
      pattern: "entity",
      description: "Full base entity with device info and coordinator",
      code: `"""Base entity for My Integration."""
from __future__ import annotations

from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN, MANUFACTURER
from .coordinator import MyCoordinator

class MyEntity(CoordinatorEntity[MyCoordinator]):
    _attr_has_entity_name = True

    def __init__(self, coordinator: MyCoordinator, device_id: str) -> None:
        super().__init__(coordinator)
        self._device_id = device_id
        self._attr_unique_id = f"{coordinator.config_entry.entry_id}_{device_id}"

    @property
    def device_info(self) -> DeviceInfo:
        return DeviceInfo(
            identifiers={(DOMAIN, self._device_id)},
            name=self.coordinator.devices[self._device_id]["name"],
            manufacturer=MANUFACTURER,
            model=self.coordinator.device_info.get("model"),
            sw_version=self.coordinator.device_info.get("sw_version"),
        )

    @property
    def available(self) -> bool:
        return super().available and self._device_id in self.coordinator.data`,
    },
  },

  service: {
    minimal: {
      pattern: "service",
      description: "Minimal service registration",
      code: `async def async_setup(hass, config):
    async def handle_my_service(call):
        entity_id = call.data.get("entity_id")
        await do_something(entity_id)

    hass.services.async_register(DOMAIN, "my_service", handle_my_service)
    return True`,
    },
    full: {
      pattern: "service",
      description: "Full service with schema validation and error handling",
      code: `"""Services for My Integration."""
from __future__ import annotations

import voluptuous as vol

from homeassistant.core import HomeAssistant, ServiceCall
from homeassistant.exceptions import HomeAssistantError, ServiceValidationError
from homeassistant.helpers import config_validation as cv

from .const import DOMAIN

SERVICE_DO_THING = "do_thing"
SERVICE_SCHEMA = vol.Schema({
    vol.Required("target"): cv.string,
    vol.Optional("value", default=100): vol.All(
        vol.Coerce(int), vol.Range(min=0, max=100)
    ),
})

async def async_setup_services(hass: HomeAssistant) -> None:
    async def handle_do_thing(call: ServiceCall) -> None:
        target = call.data["target"]
        value = call.data["value"]

        if not target:
            raise ServiceValidationError("Target is required")

        try:
            # Do the thing
            pass
        except ConnectionError as err:
            raise HomeAssistantError(f"Failed to connect: {err}") from err

    hass.services.async_register(
        DOMAIN,
        SERVICE_DO_THING,
        handle_do_thing,
        schema=SERVICE_SCHEMA,
    )`,
    },
  },

  switch: {
    minimal: {
      pattern: "switch",
      description: "Minimal switch entity",
      code: `from homeassistant.components.switch import SwitchEntity

class MySwitch(SwitchEntity):
    _attr_has_entity_name = True
    _attr_name = "Power"

    async def async_turn_on(self, **kwargs):
        await self.coordinator.client.async_turn_on()

    async def async_turn_off(self, **kwargs):
        await self.coordinator.client.async_turn_off()

    @property
    def is_on(self):
        return self.coordinator.data.get("power")`,
    },
    full: {
      pattern: "switch",
      description: "Full switch with device class and assumed state",
      code: `"""Switch platform for My Integration."""
from __future__ import annotations

from homeassistant.components.switch import SwitchDeviceClass, SwitchEntity
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .entity import MyEntity

class MySwitch(MyEntity, SwitchEntity):
    _attr_device_class = SwitchDeviceClass.OUTLET

    def __init__(self, coordinator, device_id):
        super().__init__(coordinator, device_id)
        self._attr_unique_id = f"{self._attr_unique_id}_switch"

    @property
    def is_on(self) -> bool | None:
        data = self.coordinator.data.get(self._device_id, {})
        return data.get("state")

    async def async_turn_on(self, **kwargs) -> None:
        await self.coordinator.client.async_set_state(self._device_id, True)
        await self.coordinator.async_request_refresh()

    async def async_turn_off(self, **kwargs) -> None:
        await self.coordinator.client.async_set_state(self._device_id, False)
        await self.coordinator.async_request_refresh()`,
    },
  },
};

export async function handleDocsExamples(input: ExampleInput): Promise<ExampleOutput> {
  const pattern = input.pattern.toLowerCase();
  const style = input.style || "minimal";

  const examples = EXAMPLES[pattern];
  if (!examples) {
    const available = Object.keys(EXAMPLES).join(", ");
    throw new Error(
      `Unknown pattern: ${pattern}. Available patterns: ${available}`
    );
  }

  return examples[style];
}
