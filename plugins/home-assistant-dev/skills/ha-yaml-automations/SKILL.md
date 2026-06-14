---
name: ha-yaml-automations
description: Home Assistant YAML automations — triggers, conditions, and actions. Use when writing or fixing an automation, choosing a trigger type, or structuring automation logic.
---

# Home Assistant YAML Automations

## YAML Style Rules

- **2-space indentation** (never tabs)
- **Lowercase booleans**: `true` / `false`
- **Entity IDs**: `domain.entity_name` (lowercase, underscores)

## Automation Template

```yaml
automation:
  - id: 'unique_automation_id'
    alias: 'Descriptive Name'
    description: 'What this does'
    mode: single # see Run Modes below; defaults to single if omitted
    triggers:
      - trigger: state
        entity_id: binary_sensor.front_door
        to: 'on'
    conditions:
      - condition: time
        after: '08:00:00'
        before: '22:00:00'
    actions:
      - action: light.turn_on
        target:
          entity_id: light.hallway
        data:
          brightness_pct: 100
```

## Run Modes

`mode:` controls what happens when the automation is triggered again while a previous run is still going. Omitting it defaults to `single`.

- **single** — ignore the new trigger; the in-progress run continues uninterrupted (default).
- **restart** — cancel the running run and start over from the top.
- **queued** — run sequentially; each new trigger waits in line and runs after the previous one finishes.
- **parallel** — run concurrently; each trigger starts its own run immediately.

## Common Triggers

```yaml
# State
- trigger: state
  entity_id: sensor.temperature
  above: 25

# Time
- trigger: time
  at: '07:30:00'

# Sun
- trigger: sun
  event: sunset
  offset: '-00:30:00'

# Template
- trigger: template
  value_template: "{{ states('sensor.power') | float > 1000 }}"

# Webhook
- trigger: webhook
  webhook_id: 'my_unique_webhook_id'
  allowed_methods: [POST]
```

## Common Conditions

```yaml
# State
- condition: state
  entity_id: alarm_control_panel.home
  state: 'armed_away'

# Numeric
- condition: numeric_state
  entity_id: sensor.temperature
  above: 20
  below: 30

# Time
- condition: time
  after: '08:00:00'
  before: '23:00:00'
  weekday: [mon, tue, wed, thu, fri]

# Template
- condition: template
  value_template: "{{ is_state('person.john', 'home') }}"

# AND/OR
- condition: and
  conditions:
    - condition: state
      entity_id: input_boolean.guest_mode
      state: 'off'
    - condition: state
      entity_id: binary_sensor.motion
      state: 'on'
```

## Common Actions

```yaml
# Service call
- action: light.turn_on
  target:
    entity_id: light.living_room
  data:
    brightness_pct: 80

# Delay
- delay:
    seconds: 30

# Wait for trigger
- wait_for_trigger:
    - trigger: state
      entity_id: binary_sensor.motion
      to: 'off'
  timeout:
    minutes: 5
  continue_on_timeout: true

# Choose (if/else)
- choose:
    - conditions:
        - condition: state
          entity_id: input_select.mode
          state: 'away'
      sequence:
        - action: climate.set_temperature
          target:
            entity_id: climate.thermostat
          data:
            temperature: 18
  default:
    - action: notify.mobile_app
      data:
        message: 'Unknown mode'

# Repeat
- repeat:
    count: 3
    sequence:
      - action: light.toggle
        target:
          entity_id: light.alert
      - delay:
          seconds: 1
```

## Key Rules

1. Use the plural block keys `triggers:` / `conditions:` / `actions:` (HA 2024.10+; the singular forms still work as aliases)
2. Within them use `- trigger:` / `- action:` item keys (not `- platform:` / `- service:`)
3. Always include `alias` and `description`
4. Use `target:` for entity/area/device targeting
5. Templates use Jinja2: `"{{ states('sensor.x') }}"`

## Validate / Troubleshoot

Before deploying, validate the config via **Developer Tools → YAML → Check Configuration** in the UI, or `hass --script check_config` on the CLI. Most common YAML failures:

1. **Indentation** — a tab anywhere (HA requires 2-space indent) or a misaligned list item breaks parsing.
2. **Unquoted time strings** — `at: 07:30:00` parses as a sexagesimal number; always quote them: `at: '07:30:00'`.
3. **Misplaced `!input`** — `!input` is only valid inside a blueprint; a referenced entity or input that does not exist fails the run at trigger time, not at parse time.

## Related Skills

- Scripts → `ha-scripts`
- Blueprints → `ha-blueprints`
- Device triggers → `ha-device-triggers`
