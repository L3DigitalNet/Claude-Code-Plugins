## execution commands, coverage tools, and UI testing via Charlotte or Playwright

# Stack Profile: Python / Django

## 1. Applicable Test Categories

- **Unit** — always applicable
- **Integration** — always applicable
- **E2E** — applicable (full request/response cycle tests)
- **Contract** — applicable (API schema validation for DRF projects)
- **Security** — applicable (CSRF, auth, input validation)
- **UI** — applicable when the project has a frontend (browser testing)

## 2. Test Discovery

- **Location:** `tests/` in each app, or top-level `tests/` directory
- **Naming:** files matching `test_*.py`
- **Django convention:** simple apps use `tests.py`; complex apps use a `tests/` package with `__init__.py`

| Category | Directory | Marker |
| --- | --- | --- |
| Unit | `tests/unit/` or `<app>/tests/test_models.py` | `@pytest.mark.unit` |
| Integration | `tests/integration/` or `<app>/tests/test_views.py` | `@pytest.mark.integration` |
| E2E | `tests/e2e/` | `@pytest.mark.e2e` |
| Contract | `tests/contract/` | `@pytest.mark.contract` |
| Security | `tests/security/` | `@pytest.mark.security` |

## 3. Test Execution

```bash
# pytest (recommended, with pytest-django)
DJANGO_SETTINGS_MODULE=project.settings pytest

# Django built-in test runner
python manage.py test

# By app
pytest <app>/tests/

# By marker
pytest -m integration

# Single test
pytest <app>/tests/test_views.py::TestLoginView::test_valid_credentials -v
```

Requires `DJANGO_SETTINGS_MODULE` set via environment variable or `pyproject.toml`:

```toml
[tool.pytest.ini_options]
DJANGO_SETTINGS_MODULE = "project.settings"
```

## 4. Coverage Measurement

- **Tool:** coverage.py via pytest-cov
- **Command:** `pytest --cov --cov-report=term-missing`
- **Exclude:** migrations, manage.py, wsgi/asgi files

```toml
[tool.coverage.run]
omit = ["*/migrations/*", "manage.py", "*/wsgi.py", "*/asgi.py"]
```

## 5. UI Testing

When the project has a browser-based frontend:

- **Tool:** Charlotte or Playwright for browser automation
- **Django support:** `LiveServerTestCase` launches a real HTTP server for browser tests
- **Static files:** `StaticLiveServerTestCase` serves static files during tests

```python
from django.test import LiveServerTestCase

class BrowserTest(LiveServerTestCase):
    def test_homepage_loads(self):
        # self.live_server_url provides the running server URL
        # Use Charlotte or Playwright to interact with the browser
        pass
```

For API-only Django projects (DRF without frontend), UI testing is not applicable.

## Key Testing Patterns

### Django Test Client

Built-in HTTP client for testing views without a real server:

```python
from django.test import TestCase

class ViewTests(TestCase):
    def test_homepage(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Welcome")
```

### TestCase vs TransactionTestCase

- **TestCase** — wraps each test in a transaction (rolled back after test). Fast. Use by default.
- **TransactionTestCase** — flushes the database after each test. Slower. Required when testing transaction-specific behavior (`select_for_update`, signals that fire on commit, etc.).

### factory_boy for Test Data

Preferred over fixtures for creating test objects:

```python
import factory
from myapp.models import User

class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = User
    name = factory.Faker("name")
    email = factory.Faker("email")

def test_user_display_name():
    user = UserFactory(name="Jane Doe")
    assert user.get_display_name() == "Jane Doe"
```

### pytest-django Fixtures

Key fixtures provided by pytest-django:

- `client` — Django test client
- `admin_client` — logged-in admin client
- `rf` — `RequestFactory` for unit-testing views
- `db` — database access marker (required for DB tests)
- `transactional_db` — transactional database access

## Commonly Undertested Patterns

These Django-specific patterns are frequently missed because they don't surface as standalone view functions:

- **Custom middleware**: `process_request`/`process_response`/`process_exception` — test path exemptions, header manipulation, error handling. Middleware bugs silently affect every request.
- **Signals**: `post_save`, `post_delete`, `pre_save` handlers — test that receivers fire correctly and produce expected side effects. Use `signal.disconnect()` in teardown for test isolation.
- **Model method overrides**: Custom `save()`, `delete()`, `clean()`, `__str__()` — test validation logic, cascade behavior, side effects (e.g., slug generation in `save()`).
- **Management commands**: `BaseCommand.handle()` — test with `call_command()`, verify stdout/stderr output, test error exits and `CommandError` raising.
- **Template tags and filters**: Custom tags in `templatetags/` — test rendering output with various inputs including `None`, empty strings, and HTML-unsafe content.
- **Form validation**: `clean_<field>()` and `clean()` methods — test invalid inputs, cross-field validation, specific error messages.
- **Admin customizations**: `ModelAdmin.get_queryset()`, `save_model()`, custom actions — test with `AdminSite` instance and mock requests.
- **Class-based view mixins**: `get_queryset()`, `get_context_data()`, permission mixins — test each method override independently, not just via full HTTP requests.
- **Celery/background tasks**: Async task functions — test with `task.apply()` (synchronous execution), verify retry configuration and failure handling.
- **Database constraints at application level**: Unique constraints, check constraints — test that `IntegrityError` is handled gracefully rather than producing 500 errors.

## Delegates To

- `python-dev:python-testing-patterns` for pytest fixtures, mocking, parametrize patterns
- If not installed, proceed using general pytest/Django test knowledge
