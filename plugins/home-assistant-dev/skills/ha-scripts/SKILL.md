---
name: ha-scripts
description: Home Assistant YAML scripts — callable, reusable action sequences with optional parameters. Use when creating a script, defining a reusable sequence, or adding parameterized fields to a script.
---

# Home Assistant YAML Scripts

Scripts are reusable, callable action sequences — unlike automations they have no trigger and must be called explicitly.

## YAML Style Rules

- **2-space indentation** (never tabs)
- **Lowercase booleans**: `true` / `false`
- **Entity IDs**: `domain.entity_name` (lowercase, underscores)

## Script Template

```yaml
script:
  morning_routine:
    alias: "Morning Routine"
    mode: single  # single | restart | queued | parallel
    fields:
      brightness:
        description: "Light brightness percentage"
        default: 100
        selector:
          number:
            min: 0
            max: 100
    sequence:
      - action: light.turn_on
        target:
          area_id: kitchen
        data:
          brightness_pct: "{{ brightness }}"
      - delay:
          seconds: 2
      - action: media_player.play_media
        target:
          entity_id: media_player.kitchen_speaker
        data:
          media_content_id: "good_morning_playlist"
          media_content_type: "playlist"
```

## Calling a Script

```yaml
# From an automation
- action: script.morning_routine
  data:
    brightness: 80

# From the UI: Developer Tools → Actions → script.morning_routine
```

## When to Use Scripts vs Automations

| Use Case | Choose |
|----------|--------|
| Triggered by an event or state change | Automation |
| Called by multiple automations | Script |
| Complex reusable logic | Script |
| One-off response to a trigger | Automation |

## Related Skills

- Automations → `ha-yaml-automations`
- Blueprints → `ha-blueprints`
