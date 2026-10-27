<div align="center">
  <img src="docs/assets/logo.svg" width="76" height="76" alt="moonsver logo">
  <h1>moonsver</h1>
  <p><strong><a href="https://semver.org/spec/v2.0.0.html">Semantic Versioning 2.0.0</a> for MoonBit.</strong><br>
  Parse and print versions, order them by precedence, and test ranges.</p>

  <p>
    <a href="https://moonbitstack.github.io/moonsver/"><b>Home</b></a> &nbsp;·&nbsp;
    <a href="https://moonbitstack.github.io/moonsver/guide.html"><b>Guide</b></a> &nbsp;·&nbsp;
    <a href="https://moonbitstack.github.io/moonsver/api.html"><b>API</b></a> &nbsp;·&nbsp;
    <a href="https://mooncakes.io/docs/#/moonbitstack/moonsver"><b>Mooncakes</b></a>
  </p>

  <sub>SemVer 2.0.0 · arbitrary precision · Apache-2.0</sub>
</div>

---

**moonsver** reads and writes semantic versions, compares them by the precedence rules of the spec, and evaluates version ranges. A version is a small, strict format, so the work is in the edges: leading zeroes, prerelease ordering, build metadata, and the many ways a range can be written. All of that is handled here.

The three numbers are arbitrary-precision integers, so `18446744073709551616.0.0` parses, prints and compares exactly. A range is parsed into comparator sets that you can read back, and every range grammar — npm, Cargo, Ruby or the strict spec — is a setting on one parser.

- **Arbitrary precision.** Numbers are `BigInt`, not a fixed-width integer.
- **One parser, four grammars.** The grammar is a `Syntax` value, not a separate parser.
- **Ranges as structure.** `^1.2.3` becomes `>=1.2.3, <2.0.0`; ask it anything.
- **Precedence per §11.** Build metadata is excluded, exactly as the spec says.
- **Bumps.** Major, minor, patch, the four prerelease forms, and stable.
- **JSON in and out.** Versions and ranges serialise as strings.
- **No dependencies.** Only `moonbitlang/core`.

## Install

Add the module to your package:

```moonbit
// moon.pkg
import {
  "moonbitstack/moonsver",
}
```

It exports as `@moonsver`. With the package manager, `moon add moonbitstack/moonsver` writes the same import.

## Quick start

```moonbit
fn demo() -> Unit raise @moonsver.Refused {
  // Parse and print
  let v = @moonsver.Version::parse("1.2.3-alpha.1+build.5")
  println(v.to_string())      // 1.2.3-alpha.1+build.5
  println(v.core_string())    // 1.2.3
  println(v.is_prerelease())  // true

  // Precedence (§11; build metadata stays out of it)
  let a = @moonsver.Version::parse("1.0.0-alpha")
  let b = @moonsver.Version::parse("1.0.0")
  println(a.precedence_cmp(b))  // -1

  // Ranges
  let r = @moonsver.Range::parse("^1.2.3")
  println(r.to_string())        // >=1.2.3, <2.0.0
  println(r.satisfies(@moonsver.Version::parse("1.9.0")))  // true
  println(r.satisfies(@moonsver.Version::parse("2.0.0")))  // false

  // Bumps
  println(@moonsver.Version::parse("1.2.3").inc(@moonsver.Major).to_string())  // 2.0.0
}
```

Input that does not parse raises `Refused`, which names what was wrong and where.

## Interface

### `Version`

| Method | What it does |
| --- | --- |
| `Version::parse(s, syntax?)` | Parse a string, raising `Refused`; the npm grammar is the default |
| `Version::new(major, minor, patch)` | Build from three `Int`s |
| `Version::from_bigint(major, minor, patch)` | Build from three `BigInt`s |
| `major()` / `minor()` / `patch()` | The numbers, as `BigInt` |
| `prerelease()` / `build()` | Identifier lists, as `ArrayView` |
| `is_prerelease()` / `is_stable()` | Whether a prerelease is present |
| `same_core(other)` | Do the three numbers match? |
| `core()` / `core_string()` | Drop prerelease and build metadata |
| `precedence_cmp(other)` | §11 precedence: `-1`, `0` or `1` |
| `compare(other)` | Total order: precedence, then build metadata |
| `inc(release)` | Apply a bump |
| `to_string()` | The canonical text form |

Equality is full equality: `1.0.0+a` and `1.0.0+b` are not equal, though they share a precedence.

### `Range`

| Method | What it does |
| --- | --- |
| `Range::parse(s, syntax?)` | Parse a range, raising `Refused` |
| `Range::any()` | Any version (`*`) |
| `satisfies(version)` / `satisfies_with(version, policy)` | Does the version fit? |
| `max_satisfying(versions)` / `min_satisfying(versions)` | The extreme versions that fit |
| `satisfying(versions)` | Everything that fits, sorted ascending |
| `sets()` | The disjuncts, as `ArrayView[ComparatorSet]` |
| `policy()` | The prerelease policy the range was parsed with |
| `is_any()` | Whether this is the same as any version |
| `to_string()` | Canonical text that re-parses under the same grammar |

A `Range` is the parsed structure, not the original string. Canonical output joins comparators with `, ` and disjuncts with ` || `.

### `Release`

`Major`, `Minor`, `Patch`, `PreMajor`, `PreMinor`, `PrePatch`, `Prerelease`, `Stable`. `Release::parse("major")` and `to_string()` serve config files and the command line.

| Input | Bump | Result |
| --- | --- | --- |
| `1.0.0-pre` | `Major` | `1.0.0` |
| `1.2.0-pre` | `Major` | `2.0.0` |
| `1.2.3-pre` | `Patch` | `1.2.3` |
| `1.2.3` | `Prerelease` | `1.2.4-0` |
| `1.2.3-alpha.1.2` | `Prerelease` | `1.2.3-alpha.1.3` |
| `1.2.3-alpha.beta` | `Prerelease` | `1.2.3-alpha.beta.0` |
| `1.2.3-rc.1+build` | `Stable` | `1.2.3` |

### One-liner and errors

`satisfies(version, range, syntax?)` parses two strings and answers; both are read with the same grammar.

`Refused` names what was wrong: `Empty`, `Unexpected`, `Truncated`, `Number`, `LeadingZero`, `EmptyIdentifier`, `Identifier`, `Unsupported` or `Range`. Each carries `at`, the character index of the first offending character. `at()` and `message()` read them without matching.

## Grammars

A version has one spelling in SemVer 2.0.0. Ranges are not in the spec, so different ecosystems settled on different rules. `Syntax` collects those differences as settings, and four presets are built from them:

| Preset | A bare version means | `^` | `~` | `\|\|` | Hyphen | `1.x` | `!=` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Syntax::npm()` | exact | yes | yes | yes | yes | yes | no |
| `Syntax::cargo()` | caret | yes | yes | no | no | yes | no |
| `Syntax::ruby()` | exact | no | `~>` | no | no | no | yes |
| `Syntax::strict()` | exact | no | no | no | no | no | no |

`Syntax::from_name("cargo")` and `name()` serve config files and the CLI. `Default` is the npm preset. You can also build a `Syntax` literal of your own.

<details>
<summary><b>All fourteen settings</b></summary>

| Field | What it controls |
| --- | --- |
| `default_op` | What a bare version means: `Exact`, `Caret` or `Tilde` |
| `tilde_bump` | How `~` finds its upper bound: `Patch` or `LastSpecified` |
| `allow_caret` | Accept `^` |
| `allow_tilde` | Accept `~` (`~>` only under `LastSpecified`) |
| `allow_ne` | Accept `!=` |
| `allow_or` | Accept `\|\|` |
| `allow_hyphen_range` | Accept `1.2.3 - 2.0.0` |
| `allow_xrange` | Accept `1.x`, `1.2.*` and bare `1.2` |
| `allow_empty` | Treat an empty string as any version |
| `allow_v_prefix` | Accept `v1.2.3` |
| `allow_equals_prefix` | Accept `=1.2.3` as a version literal |
| `allow_build_metadata` | Accept a `+build` segment |
| `trim` | Allow whitespace around a version literal |
| `prerelease_policy` | How prereleases are matched |

</details>

### The same string, read differently

| Written | npm | Cargo | Ruby |
| --- | --- | --- | --- |
| `1.2.3` | `=1.2.3` | `>=1.2.3, <2.0.0` | `=1.2.3` |
| `~1.2` | `>=1.2.0, <1.3.0` | `>=1.2.0, <1.3.0` | `~> 1.2` gives `>=1.2.0, <2.0.0` |
| `1.2.*` | `>=1.2.0, <1.3.0` | `>=1.2.0, <1.3.0` | not supported |

An explicit wildcard wins over `default_op`: under the Cargo preset, `1.2.*` is `>=1.2.0, <1.3.0`, not a caret range.

## Precedence

1. Compare `major`, `minor` and `patch` in turn, at arbitrary precision.
2. A version with a prerelease ranks below the same numbers without one.
3. Prerelease identifiers compare one by one: numeric by value, numeric below alphanumeric, alphanumeric in ASCII order.
4. A prefix ranks below the longer list.
5. Build metadata takes no part.

```text
1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2
            < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0
```

## Prereleases in ranges

The spec says nothing about how a range should treat prereleases. `Syntax` makes it a three-way setting:

| Policy | Meaning | Example |
| --- | --- | --- |
| `SameTuple` | Only through a comparator with the same `major.minor.patch` that carries a prerelease | `>=1.2.3-alpha` takes `1.2.3-beta`, refuses `1.2.4-beta` |
| `Always` | Compare a prerelease like any other version | `>=1.0.0` takes `1.5.0-beta` |
| `Never` | Prereleases never match | `>=1.0.0` refuses `1.5.0-beta` |

The policy is recorded in the `Range` when it is parsed, and `satisfies_with` can override it for one call.

## Command line

The `src/bin` package wraps the same functions.

```console
$ moon run src/bin -- range "^0.2.3"
>=0.2.3, <0.3.0

$ moon run src/bin -- satisfies 1.9.0 "^1.2.3"
true

$ moon run src/bin -- sort 2.0.0 1.0.0-beta 1.0.0 0.9.9
0.9.9
1.0.0-beta
1.0.0
2.0.0
```

A command exits `0` when it ran, even if the answer is `false` or nothing fits; read stdout for the answer. Bad arguments and parse failures exit non-zero with the detail on stderr.

## JSON

`Version` and `Range` implement `ToJson` / `FromJson`, serialised as strings, so they drop into config files and API responses:

```moonbit
let j = @json.to_json(@moonsver.Range::parse("^1.2.3"))
// Json::string(">=1.2.3, <2.0.0")
```

## Examples

| Example | What it shows |
|:--|:--|
| [`src/examples/tour`](src/examples/tour) | The smallest useful walk through the package |
| [`src/examples/ranges`](src/examples/ranges) | The same range under each preset, wildcards, hyphen ranges and policies |
| [`src/examples/bumps`](src/examples/bumps) | Every `Release` form against a set of inputs |
| [`src/examples/jsonio`](src/examples/jsonio) | A JSON round trip for a version and a range |

```console
$ moon run src/examples/tour
```

## License

Apache-2.0. See [LICENSE](LICENSE).
