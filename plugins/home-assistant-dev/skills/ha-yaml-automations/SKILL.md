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
  - id: "unique_automation_id"
    alias: "Descriptive Name"
    description: "What this does"
    mode: single  # single | restart | queued | parallel
    trigger:
      - trigger: state
        entity_id: binary_sensor.front_door
        to: "on"
    condition:
      - condition: time
        after: "08:00:00"
        before: "22:00:00"
    action:
      - action: light.turn_on
        target:
          entity_id: light.hallway
        data:
          brightness_pct: 100
```

## Common Triggers

```yaml
# State
- trigger: state
  entity_id: sensor.temperature
  above: 25

# Time
- trigger: time
  at: "07:30:00"

# Sun
- trigger: sun
  event: sunset
  offset: "-00:30:00"

# Template
- trigger: template
  value_template: "{{ states('sensor.power') | float > 1000 }}"

# Webhook
- trigger: webhook
  webhook_id: "my_unique_webhook_id"
  allowed_methods: [POST]
```

## Common Conditions

```yaml
# State
- condition: state
  entity_id: alarm_control_panel.home
  state: "armed_away"

# Numeric
- condition: numeric_state
  entity_id: sensor.temperature
  above: 20
  below: 30

# Time
- condition: time
  after: "08:00:00"
  before: "23:00:00"
  weekday: [mon, tue, wed, thu, fri]

# Template
- condition: template
  value_template: "{{ is_state('person.john', 'home') }}"

# AND/OR
- condition: and
  conditions:
    - condition: state
      entity_id: input_boolean.guest_mode
      state: "off"
    - condition: state
      entity_id: binary_sensor.motion
      state: "on"
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
      to: "off"
  timeout:
    minutes: 5
  continue_on_timeout: true

# Choose (if/else)
- choose:
    - conditions:
        - condition: state
          entity_id: input_select.mode
          state: "away"
      sequence:
        - action: climate.set_temperature
          target:
            entity_id: climate.thermostat
          data:
            temperature: 18
  default:
    - action: notify.mobile_app
      data:
        message: "Unknown mode"

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

1. Use `action:` not `service:` (modern syntax)
2. Use `trigger:` as type key (not `platform:`)
3. Always include `alias` and `description`
4. Use `target:` for entity/area/device targeting
5. Templates use Jinja2: `"{{ states('sensor.x') }}"`

## Related Skills

- Scripts → `ha-scripts`
- Blueprints → `ha-blueprints`
- Device triggers → `ha-device-triggers`
