# linguist

A fast, zero-dependency source code language statistics tool. Single static binary, ~108KB.

Written in Modula-2, compiled via [m2c](https://github.com/fitzee/m2c).

## Why not github-linguist?

GitHub's [linguist](https://github.com/github-linguist/linguist) is the gold standard for repository language detection. It's also a Ruby gem with a transitive dependency graph that pulls in half of RubyGems, requires a working Ruby installation, and takes non-trivial effort to install on a clean machine.

This project exists because sometimes you just want to run `linguist .` and get a table of stats without fighting `bundle install` for twenty minutes.

### What's the same

- Recursive directory scanning
- `.gitignore` support (nested, negation patterns, `**` globs)
- `.gitattributes` support (`linguist-vendored`, `linguist-generated`, `linguist-documentation`, `linguist-language`)
- Detection by file extension, well-known filename, and shebang line
- Binary file exclusion (NUL byte and control character heuristic)
- Symlink skipping
- Sorted by bytes descending, with percentage breakdown

### What's different

| | github-linguist | this |
|---|---|---|
| Runtime | Ruby + native extensions | Single static binary |
| Install | `gem install github-linguist` + deps | Copy one file |
| Binary size | ~50MB installed | 108KB |
| Speed | Seconds on large repos | Milliseconds |
| Language DB | 600+ languages, Bayesian classifier, heuristics | ~90 languages by extension/filename/shebang |
| Disambiguation | Statistical classifier for ambiguous extensions | First-match (no classifier) |
| Git integration | Reads from Git blob objects | Reads the working tree directly |
| Configuration | Overrides via `.gitattributes` | Same |
| Vendored detection | Built-in path patterns | Via `.gitattributes` only |
| Generated detection | Content heuristics + patterns | Via `.gitattributes` only |

The main trade-off: github-linguist has a massive language database and a Bayesian classifier that can distinguish, say, Objective-C `.h` files from C `.h` files by looking at the content. This tool doesn't do that. It maps `.h` to C and moves on. For most codebases this is fine. If you need per-file disambiguation of ambiguous extensions, use the real thing.

## Install

Build from source (requires [m2c](https://github.com/mattfitz/m2c)):

```
cd linguist
m2c build
```

Binary lands in `.m2c/bin/linguist`. Copy it wherever you like.

## Usage

```
linguist [options] [directory]
```

If no directory is given, scans the current directory.

### Options

| Flag | Description |
|---|---|
| `-h`, `--help` | Show help and exit |
| `-j`, `--json` | Output as JSON instead of a table |
| `-b`, `--breakdown` | List individual files per language |
| `--no-vendored` | Exclude files marked `linguist-vendored` in `.gitattributes` |
| `--no-generated` | Exclude files marked `linguist-generated` in `.gitattributes` |

### Examples

**Basic usage** -- scan the current directory:

```
$ linguist .
Language  Lines  Bytes  Files  Percentage
--------  -----  -----  -----  ----------
Modula-2  1437   38964  16     98.4%
TOML      18     414    1      1.0%
C         10     173    1      0.2%
Total     1465   39551  18     100.0%
```

**Scan a specific directory:**

```
$ linguist ~/projects/my-compiler
Language       Lines   Bytes    Files  Percentage
-------------  ------  -------  -----  ----------
Modula-2       50351   1438838  409    36.1%
Rust           24180   941055   40     23.6%
Markdown       24638   830021   222    20.8%
C              17498   610041   25     15.3%
Python         1656    66402    1      1.6%
JSON           1052    30989    7      0.7%
TypeScript     647     21132    1      0.5%
Shell          651     18175    6      0.4%
TOML           524     10195    30     0.2%
Objective-C++  291     9772     2      0.2%
YAML           68      1805     1      0.0%
Total          121556  3978425  744    100.0%
```

**JSON output** for scripting:

```
$ linguist --json .
{"languages":{"Modula-2":{"bytes":38964,"files":16,"lines":1437,"percentage":"98.4"},"TOML":{"bytes":414,"files":1,"lines":18,"percentage":"1.0"},"C":{"bytes":173,"files":1,"lines":10,"percentage":"0.2"}},"total_bytes":39551,"total_files":18,"total_lines":1465}
```

**Breakdown** -- see which files belong to each language:

```
$ linguist --breakdown .
Language  Lines  Bytes  Files  Percentage
--------  -----  -----  -----  ----------
Modula-2  1437   38964  16     98.4%
TOML      18     414    1      1.0%
C         10     173    1      0.2%
Total     1465   39551  18     100.0%

Modula-2
  src/Stats.mod
  src/Detect.def
  src/Output.mod
  src/Attrs.mod
  src/Ignore.def
  ...
TOML
  m2.toml
C
  src/bridge.c
```

JSON breakdown adds a `file_list` array to each language entry.

## How detection works

Detection runs in order. The first match wins.

1. **`.gitattributes` override** -- if a file matches a pattern with `linguist-language=X`, that language is used unconditionally.

2. **File extension** -- the most common path. Maps `.rs` to Rust, `.py` to Python, etc. Case-insensitive matching.

3. **Well-known filename** -- files like `Makefile`, `Dockerfile`, `CMakeLists.txt` are recognised by exact name.

4. **Shebang** -- if the file has no recognised extension, the first line is checked for `#!`. Interpreter names like `python3`, `bash`, `node` are mapped to languages.

If none of the above match, the file is ignored (not counted).

## What gets skipped

- **Binary files** -- detected by NUL bytes or high control character ratio (>5%) in the first 8KB
- **Hidden files** -- anything starting with `.` (including `.git`, `.DS_Store`)
- **Well-known non-source directories** -- `.git`, `.hg`, `.svn`, `node_modules`
- **Symlinks** -- always skipped
- **`.gitignore` patterns** -- loaded per-directory, supports nested `.gitignore` files, negation (`!pattern`), directory-only patterns (`dir/`), and `**` globs
- **`.gitattributes` markers** -- files marked `linguist-vendored`, `linguist-generated`, or `linguist-documentation` are excluded (when the corresponding flags are set, or for documentation always)

## Supported languages

~90 languages detected by extension. Partial list of the more common ones:

Ada, Assembly, Awk, Batch, C, C#, C++, CMake, CSS, Clojure, COBOL, Common Lisp, D, Dart, Diff, Dockerfile, Elixir, Emacs Lisp, Erlang, F#, Fortran, Go, GraphQL, Groovy, HCL, HTML, Haskell, INI, JSON, Java, JavaScript, Julia, Just, Kotlin, Less, Lua, Makefile, Markdown, Modula-2, Nim, Nix, OCaml, Objective-C, Objective-C++, PHP, Pascal, Perl, PowerShell, Protocol Buffers, Python, R, Racket, Ruby, Rust, SCSS, SQL, SVG, Sass, Scala, Scheme, Shell, Swift, Tcl, TeX, TOML, TypeScript, V, Vim Script, Visual Basic, XML, YAML, Zig.

## Limits

- Max 4096 files tracked for `--breakdown` output (stats are always unlimited)
- Max 128 distinct languages per scan
- Max 512 `.gitignore` patterns loaded at once
- Max 128 `.gitattributes` rules loaded at once
- Paths longer than 1023 characters are truncated
- No disambiguation of ambiguous extensions (`.h` is always C, never C++ or Objective-C)
- No content-based classification
- Working tree only -- does not read Git objects or respect `.gitattributes` set via `git config`
