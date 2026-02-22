# gcov + lcov Coverage Workflow Reference

## Prerequisites

```bash
# Debian/Ubuntu
sudo apt-get install gcov lcov

# Fedora/RHEL
sudo dnf install gcc lcov

# macOS (requires GCC from Homebrew; Apple Clang uses llvm-cov instead)
brew install gcc lcov
```

Note: With Clang on macOS, replace `gcov` references with `llvm-cov gcov`.

## CMake Coverage Presets

### CMakePresets.json (Recommended)

```json
{
  "version": 3,
  "configurePresets": [
    {
      "name": "coverage",
      "displayName": "Coverage Build",
      "binaryDir": "${sourceDir}/build-coverage",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Debug",
        "ENABLE_COVERAGE": "ON"
      }
    }
  ],
  "buildPresets": [
    {
      "name": "coverage",
      "configurePreset": "coverage"
    }
  ],
  "testPresets": [
    {
      "name": "coverage",
      "configurePreset": "coverage",
      "output": { "outputOnFailure": true }
    }
  ]
}
```

Usage:
```bash
cmake --preset coverage
cmake --build --preset coverage
ctest --preset coverage
```

### CMakeLists.txt Coverage Option

```cmake
option(ENABLE_COVERAGE "Enable gcov/lcov coverage instrumentation" OFF)

if(ENABLE_COVERAGE)
    if(NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
        message(WARNING "Coverage builds should use Debug mode for accurate line mapping")
    endif()
    add_compile_options(-O0 -g --coverage -fprofile-arcs -ftest-coverage)
    add_link_options(--coverage)
    # Clang alternative: -fprofile-instr-generate -fcoverage-mapping
endif()
```

## Full lcov Workflow

```bash
#!/usr/bin/env bash
# Full coverage collection sequence

BUILD_DIR="build-coverage"
SRC_DIR="$(pwd)"
OUTPUT_DIR="htmlcov"

# 1. Build
cmake -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Debug -DENABLE_COVERAGE=ON
cmake --build "$BUILD_DIR" --parallel

# 2. Zero out any stale counters from previous runs
lcov --zerocounters --directory "$BUILD_DIR"

# 3. Run tests (generates .gcda files in build dir)
cd "$BUILD_DIR"
ctest --output-on-failure
cd "$SRC_DIR"

# 4. Capture coverage data
lcov --capture \
     --directory "$BUILD_DIR" \
     --output-file coverage_raw.info \
     --no-external \             # exclude /usr/include and Qt headers
     --gcov-tool gcov            # use 'llvm-cov gcov' on macOS with Clang

# 5. Remove noise: tests, moc files, UI-generated files
lcov --remove coverage_raw.info \
     '*/tests/*' \
     '*/moc_*' \
     '*/ui_*' \
     '*/build-coverage/*' \
     --output-file coverage.info

# 6. Display summary
lcov --summary coverage.info

# 7. Generate browsable HTML report
genhtml coverage.info \
        --output-directory "$OUTPUT_DIR" \
        --title "$(basename $SRC_DIR) Coverage" \
        --legend \
        --show-details \
        --demangle-cpp            # requires c++filt

echo "Report: $OUTPUT_DIR/index.html"
```

## Parsing Coverage for Gap Identification

Extract files below threshold from lcov summary:

```bash
THRESHOLD=80

lcov --summary coverage.info 2>&1 | \
    grep "\.cpp\|\.h" | \
    awk -F'[(%]' '{
        file=$1; pct=$2
        if (pct+0 < '"$THRESHOLD"')
            print pct"% - "file
    }' | sort -n
```

Extract specific uncovered lines from lcov data file:

```bash
# Parse lcov .info file for DA (line data) entries with hit count 0
grep -E "^(SF:|DA:)" coverage.info | \
    awk '/^SF:/{file=$0} /^DA:/{split($0,a,":"); split(a[2],b,","); if(b[2]==0) print file" line "b[1]}'
```

## Clang/LLVM Coverage Alternative

If using Clang (especially on macOS):

```cmake
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-fprofile-instr-generate -fcoverage-mapping)
    add_link_options(-fprofile-instr-generate)
endif()
```

Collect:
```bash
# After running tests:
llvm-profdata merge -sparse *.profraw -o coverage.profdata
llvm-cov report ./my_test -instr-profile=coverage.profdata
llvm-cov show ./my_test -instr-profile=coverage.profdata \
    -format=html -output-dir=htmlcov
```

## Troubleshooting

**`.gcda` files not generated**: Tests never ran, or ran with a different binary. Verify `ctest` ran successfully before `lcov --capture`.

**Coverage shows 0% for all files**: `-fprofile-arcs -ftest-coverage` missing from compile flags. Verify `ENABLE_COVERAGE=ON` was actually applied.

**`--no-external` misses Qt headers from non-system paths**: If Qt is installed in a custom prefix (not `/usr`), exclude it explicitly: `lcov --remove coverage_raw.info '/opt/qt6/*'`.

**`genhtml: demangle failed`**: `c++filt` not installed, or remove `--demangle-cpp` flag.

**Different results across runs**: Object files from non-instrumented builds mixing with instrumented ones. Run `cmake --build --clean-first` after enabling coverage.
