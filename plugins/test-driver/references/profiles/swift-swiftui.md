# Stack Profile: Swift / SwiftUI

discovery conventions, execution commands, coverage tools, and UI testing via XCUITest

## 1. Applicable Test Categories

- **Unit** — always applicable
- **Integration** — always applicable
- **UI** — applicable (XCUITest for UI automation)
- **E2E** — not applicable (covered by UI tests in iOS context)
- **Contract** — not applicable
- **Security** — not applicable

## 2. Test Discovery

**Swift Package Manager (SPM) projects:**

- **Location:** `Tests/` directory
- **Naming:** files matching `*Tests.swift` containing `XCTestCase` subclasses or `@Test` functions
- **Test targets:** defined in `Package.swift` under `testTarget`

**Xcode projects:**

- **Location:** test targets in `.xcodeproj` or `.xcworkspace`
- **Naming:** test classes inheriting from `XCTestCase`
- **UI tests:** separate test target (e.g., `MyAppUITests`)

## 3. Test Execution

```bash
# SPM: run all tests
swift test

# SPM: run specific test class
swift test --filter MyTests.AuthTests

# SPM: run specific test method
swift test --filter MyTests.AuthTests/testLoginSuccess

# Xcode: run all tests for a scheme
xcodebuild test \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Xcode: run specific test class
xcodebuild test \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:MyAppTests/AuthTests
```

## 4. Coverage Measurement

**SPM:**

```bash
# Enable coverage collection
swift test --enable-code-coverage

# Export coverage report
xcrun llvm-cov report \
  .build/debug/MyPackagePackageTests.xctest/Contents/MacOS/MyPackagePackageTests \
  --instr-profile .build/debug/codecov/default.profdata

# Export as JSON for programmatic use
xcrun llvm-cov export \
  .build/debug/MyPackagePackageTests.xctest/Contents/MacOS/MyPackagePackageTests \
  --instr-profile .build/debug/codecov/default.profdata \
  --format lcov > coverage.lcov
```

**Xcode:**

- Built-in coverage reports via Xcode organizer (Product > Test with coverage enabled)
- `xcodebuild test -enableCodeCoverage YES` for CI

## 5. UI Testing

### XCUITest

Apple's UI testing framework for iOS, macOS, watchOS, and tvOS.

**Application launch:**

```swift
let app = XCUIApplication()
app.launch()
```

**Element queries:**

```swift
// Find elements by accessibility identifier or label
let loginButton = app.buttons["Login"]
let emailField = app.textFields["Email"]
let errorLabel = app.staticTexts["Invalid credentials"]

// Navigation elements
let settingsTab = app.tabBars.buttons["Settings"]
let backButton = app.navigationBars.buttons.element(boundBy: 0)
```

**Interactions:**

```swift
emailField.tap()
emailField.typeText("user@example.com")
loginButton.tap()
```

**Assertions:**

```swift
XCTAssertTrue(app.staticTexts["Welcome"].exists)
XCTAssertTrue(loginButton.isEnabled)
XCTAssertFalse(errorLabel.exists)

// Wait for elements to appear
let exists = app.staticTexts["Welcome"].waitForExistence(timeout: 5)
XCTAssertTrue(exists)
```

**Example UI test:**

```swift
import XCTest

class LoginUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testSuccessfulLogin() throws {
        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"]
        let loginButton = app.buttons["Login"]

        emailField.tap()
        emailField.typeText("user@example.com")
        passwordField.tap()
        passwordField.typeText("password123")
        loginButton.tap()

        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5))
    }
}
```

## Key Testing Patterns

### XCTestCase (unit tests)

```swift
import XCTest
@testable import MyApp

class CalculatorTests: XCTestCase {
    var calculator: Calculator!

    override func setUpWithError() throws {
        calculator = Calculator()
    }

    override func tearDownWithError() throws {
        calculator = nil
    }

    func testAddition() throws {
        XCTAssertEqual(calculator.add(2, 3), 5)
    }

    func testDivisionByZero() throws {
        XCTAssertThrowsError(try calculator.divide(10, 0)) { error in
            XCTAssertEqual(error as? CalcError, .divisionByZero)
        }
    }
}
```

### Swift Testing (@Test macro, Swift 5.9+)

The newer `swift-testing` framework uses `@Test` and `#expect`:

```swift
import Testing
@testable import MyApp

@Test func addition() {
    let calc = Calculator()
    #expect(calc.add(2, 3) == 5)
}

@Test func divisionByZero() {
    let calc = Calculator()
    #expect(throws: CalcError.divisionByZero) {
        try calc.divide(10, 0)
    }
}
```

### Async Testing

```swift
func testAsyncFetch() async throws {
    let service = DataService()
    let result = try await service.fetchItems()
    XCTAssertFalse(result.isEmpty)
}
```

## Commonly Undertested Patterns

These Swift/SwiftUI-specific patterns are frequently missed because they involve reactive state and concurrency:

- **@Observable / @StateObject lifecycle**: Test that published property changes trigger downstream reactions — use `@MainActor` test methods to ensure main-thread assertions.
- **Async/await error paths**: `Task` cancellation handling, `try await` failure branches — test with `Task.cancel()` and verify cleanup runs. Use `XCTAssertThrowsError` for async functions.
- **Navigation state**: `NavigationPath` mutations, deep link URL parsing — test programmatic navigation and back-stack behavior.
- **Combine publisher chains**: `publisher.sink()` sequences — test with `XCTestExpectation` and timeout, verify cancellation cleanup.
- **CoreData / SwiftData**: Model CRUD operations, migration paths, fetch request predicates, cascade delete rules.
- **Codable conformance**: Custom `init(from:)` and `encode(to:)` — test with malformed JSON, missing optional fields, unexpected types, and round-trip encoding.
- **Protocol default implementations**: Protocol extensions with default behavior — test that conforming types correctly override defaults and that the defaults themselves work.
- **Actor isolation**: `@MainActor` and custom actors — test concurrent access patterns, verify that `nonisolated` methods don't access actor-isolated state.

## Delegates To

Self-contained; no existing Swift testing plugin. If a Swift testing plugin is added in the future, this profile should be updated to delegate framework specifics.
