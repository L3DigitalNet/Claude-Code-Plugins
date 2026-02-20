---
name: ha-blueprints
description: Home Assistant YAML blueprints — reusable automation templates with configurable inputs. Use when building a blueprint, defining blueprint inputs, or creating a shareable automation template.
---

# Home Assistant YAML Blueprints

Blueprints are reusable automation templates with configurable inputs — users can create multiple automations from the same blueprint with different settings.

## YAML Style Rules

- **2-space indentation** (never tabs)
- **Lowercase booleans**: `true` / `false`

## Blueprint Template

```yaml
blueprint:
  name: "Motion-Activated Light"
  description: "Turn on light when motion detected, turn off after delay"
  domain: automation
  input:
    motion_entity:
      name: "Motion Sensor"
      selector:
        entity:
          filter:
            domain: binary_sensor
            device_class: motion
    light_target:
      name: "Light"
      selector:
        target:
          entity:
            domain: light
    no_motion_wait:
      name: "Wait time after motion stops"
      default: 120
      selector:
        number:
          min: 0
          max: 3600
          unit_of_measurement: seconds

trigger:
  - trigger: state
    entity_id: !input motion_entity
    to: "on"

action:
  - action: light.turn_on
    target: !input light_target
  - wait_for_trigger:
      - trigger: state
        entity_id: !input motion_entity
        to: "off"
  - delay:
      seconds: !input no_motion_wait
  - action: light.turn_off
    target: !input light_target

mode: restart
```

## Key Blueprint Concepts

- **`!input`** — References a user-provided input value anywhere in the blueprint body
- **`selector`** — Controls what UI picker appears in HA's frontend for each input
- **`domain: automation`** — Blueprints can also target `script` domain
- **`default`** — Makes an input optional (uses default if not set)

## Common Selectors

```yaml
# Entity picker
selector:
  entity:
    filter:
      domain: light

# Area picker
selector:
  area: {}

# Number slider
selector:
  number:
    min: 0
    max: 100
    unit_of_measurement: "%"

# Boolean toggle
selector:
  boolean: {}

# Time picker
selector:
  time: {}
```

## Sharing Blueprints

Save blueprint files to `config/blueprints/automation/your-name/blueprint-name.yaml`. Share via GitHub — users import with the raw file URL.

## Related Skills

- Automations → `ha-yaml-automations`
- Scripts → `ha-scripts`
