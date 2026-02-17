---
name: ha-async-patterns
description: Write correct async Python code for Home Assistant integrations. Use when mentioning async, await, event loop, blocking, executor, async_add_executor_job, coroutine, or asking about performance and non-blocking code in Home Assistant.
---

# Async Python Patterns in Home Assistant

Home Assistant runs on a **single-threaded asyncio event loop**. All I/O must be non-blocking. Blocking the loop freezes automations, the UI, and entity updates.

## Pattern 1: Async Libraries (Preferred)

```python
import aiohttp

async def async_get_data(self) -> dict:
    async with aiohttp.ClientSession() as session:
        async with session.get(f"http://{self._host}/api") as response:
            response.raise_for_status()
            return await response.json()
```

## Pattern 2: Wrapping Sync Libraries

When no async library exists:

```python
import requests

async def async_get_data(self) -> dict:
    return await self.hass.async_add_executor_job(self._sync_get_data)

def _sync_get_data(self) -> dict:
    response = requests.get(f"http://{self._host}/api", timeout=10)
    response.raise_for_status()
    return response.json()
```

With arguments:

```python
# Positional args after callable
result = await hass.async_add_executor_job(requests.get, url, {"timeout": 10})

# Keyword args with functools.partial
from functools import partial
result = await hass.async_add_executor_job(
    partial(requests.get, url, timeout=10, headers=headers)
)
```

## Pattern 3: Callbacks vs Coroutines

```python
from homeassistant.core import callback

# @callback = sync, runs on event loop, NO I/O allowed
@callback
def _handle_coordinator_update(self) -> None:
    self._attr_native_value = self.coordinator.data.get("value")
    self.async_write_ha_state()

# async = coroutine, CAN do I/O
async def async_turn_on(self, **kwargs) -> None:
    await self.coordinator.client.async_set_state(True)
    await self.coordinator.async_request_refresh()
```

## Pattern 4: Timeouts

```python
import asyncio

async def async_get_data(self) -> dict:
    try:
        async with asyncio.timeout(10):
            return await self.client.async_get_data()
    except TimeoutError:
        raise UpdateFailed("Request timed out")
```

## Pattern 5: Event Listeners

```python
async def async_setup_entry(hass, entry):
    @callback
    def handle_event(event: Event) -> None:
        # No I/O here — schedule async work
        hass.async_create_task(async_process(event))

    async def async_process(event: Event) -> None:
        await some_async_work(event.data)

    unsub = hass.bus.async_listen("state_changed", handle_event)
    entry.async_on_unload(unsub)
    return True
```

## Pattern 6: Background Tasks

```python
# For fire-and-forget tasks
hass.async_create_task(my_coroutine())

# For long-running background tasks
entry.async_create_background_task(
    hass, my_long_running_task(), "task_name"
)
```

## Common Mistakes

```python
# WRONG - blocks event loop
data = requests.get(url)
time.sleep(5)
open("file.txt").read()

# RIGHT
data = await hass.async_add_executor_job(requests.get, url)
await asyncio.sleep(5)
data = await hass.async_add_executor_job(Path("file.txt").read_text)
```

```python
# WRONG - sync method still blocks
def get_data(self):
    return requests.get(url)

async def _async_update_data(self):
    return self.get_data()  # Still blocking!

# RIGHT
async def _async_update_data(self):
    return await self.hass.async_add_executor_job(self.get_data)
```

```python
# WRONG - task may be garbage collected
asyncio.create_task(my_coroutine())

# RIGHT - use HA's task management
hass.async_create_task(my_coroutine())
```
