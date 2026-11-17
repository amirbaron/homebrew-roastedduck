# roastedDuck Homebrew tap

Install the independently maintained Rust engine with its bundled implementations of
DuckDB's httpfs, aws, azure, icu, postgres_scanner, fts and vss extensions:

```sh
brew install amirbaron/roastedduck/roastedduck
roastedduck
```

Then load the implementations you need:

```sql
LOAD httpfs;
LOAD postgres;
LOAD fts;
```

No separate extension packages or binary downloads are required. HNSW indexes
currently require an in-memory database. This public preview targets DuckDB 1.5.6;
it is not an official DuckDB release.

Supported archives: macOS Apple Silicon, Linux x86_64 and Linux arm64 (glibc 2.28+).
The tap installs the CLI and notices; it does not replace upstream `duckdb`.

- [Project and source](https://github.com/amirbaron/roastedDuck)
- [Extension guide](https://amirbaron.github.io/roastedDuck/extensions/)
- [Releases and SHA256SUMS](https://github.com/amirbaron/roastedDuck/releases)

The formula pins qualified native SDK archive hashes. Homebrew bottles package
those verified binaries and are tested after pouring on clean runners. Upgrades use
`brew update && brew upgrade amirbaron/roastedduck/roastedduck`.
Run the package checks with `brew test amirbaron/roastedduck/roastedduck`.
