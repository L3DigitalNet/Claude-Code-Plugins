# Redaction Reference

## async_redact_data Behavior

The helper recursively redacts matching keys anywhere in the nested structure. Redacted values become `"**REDACTED**"`.

```python
from homeassistant.components.diagnostics import async_redact_data

data = {
    "device": {
        "name": "Living Room",
        "serial": "ABC123",  # Will be redacted
        "firmware": "1.2.3",
    },
    "auth": {
        "token": "secret123",  # Will be redacted
        "expires": 3600,
    }
}

redacted = async_redact_data(data, {"serial", "token"})
# Result:
# {
#     "device": {"name": "Living Room", "serial": "**REDACTED**", "firmware": "1.2.3"},
#     "auth": {"token": "**REDACTED**", "expires": 3600}
# }
```

## Redaction Decision Table

| Category | Keys to Redact | Always? |
|----------|---------------|---------|
| **Auth** | `password`, `token`, `api_key`, `access_token`, `refresh_token`, `secret`, `credentials`, `auth` | Yes |
| **Personal** | `email`, `username`, `user_id`, `account_id` | Yes |
| **Device IDs** | `serial`, `serial_number`, `unique_id`, `mac`, `mac_address` | Yes |
| **Location** | `latitude`, `longitude`, `lat`, `lon`, `location`, `address`, `coordinates` | Yes |
| **Network** | `ip_address`, `ip`, `ssid` | Consider context |
| **Phone numbers** | varies | Consider |
| **Names** | varies | If personally identifiable |
| **URLs with auth tokens** | varies | Use custom redaction |
| **Custom identifiers** | integration-specific | Consider |

## Never Redact

- Model numbers
- Firmware versions
- Feature flags
- Error messages
- Timestamps
- Entity states (unless containing PII)
