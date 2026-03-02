# ripgrep Documentation

## Man Pages

- `man rg` — full flag reference, configuration file, type definitions, regex syntax

## Official

- ripgrep source (GitHub): https://github.com/BurntSushi/ripgrep
- ripgrep releases: https://github.com/BurntSushi/ripgrep/releases
- ripgrep user guide: https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md

## Configuration and Types

- Configuration file (`RIPGREP_CONFIG_PATH`): https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#configuration-file
- Built-in file type list: run `rg --type-list`
- Custom type definitions (`--type-add`): https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#manual-filtering-file-types

## Regex Reference

- Rust regex crate (default engine): https://docs.rs/regex/latest/regex/
- Rust regex syntax summary: https://docs.rs/regex/latest/regex/#syntax
- PCRE2 syntax (used with `rg -P`): https://www.pcre.org/current/doc/html/pcre2syntax.html

## Comparisons and Background

- ripgrep vs grep vs ag vs ack: https://github.com/BurntSushi/ripgrep#quick-examples-comparing-tools
- Performance benchmarks: https://blog.burntsushi.net/ripgrep/
