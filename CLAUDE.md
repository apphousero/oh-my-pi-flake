# omp

Nix flake packaging [`can1357/oh-my-pi`](https://github.com/can1357/oh-my-pi) (`omp`) for NixOS and Home Manager. That repo is the source of releases and assets; for questions about how `omp` itself works, consult [deepwiki.com/can1357/oh-my-pi](https://deepwiki.com/can1357/oh-my-pi) rather than the official docs.

| File | Purpose |
| --- | --- |
| `package.nix` | The derivation. Version and per-platform asset hashes live here. |
| `flake.nix` | Outputs: `packages`, `devShells`, `overlays.default`, `homeManagerModules.default`. |
| `module.nix` | Home Manager module exposing `services.oh-my-pi.enable`. |

## Packaging model: prebuilt binaries, not a source build

`package.nix` fetches the official per-platform release asset and runs `autoPatchelfHook` on it. It does **not** compile from source.

Do not "restore" the source build. It was removed deliberately, and each of these was reproduced before the decision:

1. Upstream deleted the root `build:native` script. Natives now build through `packages/natives run build`, which drives **Bazel** (`scripts/bazel-natives.ts`), downloading hermetic zig and Rust toolchains at build time.
2. The cargo fallback (`packages/natives run build:bindings`) is broken outside Bazel. `audiopus_sys` installs `libopus.a` to `<prefix>/lib64` while its `build.rs` links `<prefix>/lib`. Upstream fixes this only inside their Bazel toolchain, via `bazel/patches/audiopus-sys-libdir.patch`.
3. `pi-natives` uses `#![feature(alloc_error_hook)]`, so it needs the exact nightly pinned in upstream `rust-toolchain.toml`, not `rust-bin.nightly.latest`.
4. Blocking: upstream requires Bun `>= 1.3.14`; nixpkgs ships `1.3.13`. A binary compiled with `1.3.13` embeds that runtime and refuses to start with `error: Bun runtime must be >= 1.3.14`. A source build cannot produce a working `omp` without also vendoring a Bun derivation.

Two consequences worth preserving:

- The derivation is pure. There is no `__noChroot`, so **`--option sandbox relaxed` is not needed**. If you ever find yourself adding `__noChroot` back, something has gone wrong.
- `flake.nix` has no `rust-overlay` input. Do not re-add one.

## Updating to a new version

### 1. Pick the version

```sh
curl -sL https://api.github.com/repos/can1357/oh-my-pi/releases/latest | jq -r .tag_name
```

### 2. Confirm the asset names still match

`package.nix` maps each Nix system to a release asset filename. Upstream has renamed assets before, so check rather than assume:

```sh
VERSION=17.2.6   # no leading "v"
curl -sL "https://api.github.com/repos/can1357/oh-my-pi/releases/tags/v$VERSION" | jq -r '.assets[].name'
```

Expect `omp-linux-x64`, `omp-linux-arm64`, `omp-darwin-x64`, `omp-darwin-arm64`. The `musl`, `windows`, and `browser-relay-extension` assets are intentionally unpackaged.

### 3. Regenerate the `sources` block

Set `VERSION`, then run. This prints the complete attrset body, ready to paste over the existing `sources = { ... }` contents in `package.nix`:

```sh
VERSION=17.2.6
for pair in \
  "x86_64-linux:omp-linux-x64" \
  "aarch64-linux:omp-linux-arm64" \
  "x86_64-darwin:omp-darwin-x64" \
  "aarch64-darwin:omp-darwin-arm64"
do
  sys=${pair%%:*}; asset=${pair##*:}
  hash=$(nix store prefetch-file --json --hash-type sha256 \
    "https://github.com/can1357/oh-my-pi/releases/download/v$VERSION/$asset" | jq -r .hash)
  printf '    %s = {\n      asset = "%s";\n      hash = "%s";\n    };\n' "$sys" "$asset" "$hash"
done
```

This downloads roughly 600 MB across the four assets and takes a minute or two.

### 4. Bump `version` in `package.nix`

The `let version = "..."` binding feeds the download URL, the `installCheck` assertion, and `meta.downloadPage`. It is the only place the version string is written.

### 5. Verify

All four must pass before committing:

```sh
nix build .#oh-my-pi --no-link --print-out-paths   # installCheck runs --version and --smoke-test
nix build .#oh-my-pi --no-link --rebuild           # reproducibility
nix flake check
nix run .#oh-my-pi -- --version                    # expect omp/<version>
```

A wrong hash fails at fetch time with `hash mismatch`; a wrong *asset name* fails with a 404. Both surface immediately, so a clean `nix build` is meaningful.

For a full end-to-end check that the package composes into a system closure, build a throwaway NixOS `system-path` with the overlay applied. That is the derivation that fails first in a real `nixos-rebuild`.

## Gotchas

- **`installCheck` needs a writable `HOME`.** `omp` extracts its embedded native addon to `$HOME/.omp/natives/<version>/` on first run. Without `export HOME=$(mktemp -d)` the check dies on `EACCES ... '/homeless-shelter'`. Keep that line.
- **The extracted `.node` is not patchelf'd.** It is unpacked at runtime, after the build, so `autoPatchelfHook` never sees it. This is fine only because it links nothing beyond glibc. If a future release makes that addon depend on more libraries, it will fail at runtime while the build still passes; a wrapper setting `LD_LIBRARY_PATH` would then be required.
- **`x86_64-darwin` is being retired by nixpkgs, and the symptom depends on the pin.** On the current FlakeHub pin (26.05) it evaluates and only emits a deprecation warning. On nixpkgs 26.11 and later the platform is gone and evaluating that system is a hard error, which `nix flake check` reports as an omitted incompatible system. Either way it is a nixpkgs decision, not a fault in this flake. The entry is kept because the upstream asset exists.
- **Do not add `stdenv.cc.cc.libgcc`** to `buildInputs`. It was tested and is unnecessary; glibc arrives via stdenv.
- **Hashes are SRI (`sha256-...`), not raw hex.** `nix store prefetch-file --json | jq -r .hash` already emits the right format.

## Style

Per the user's global instruction: no comments in Nix source. If one is genuinely unavoidable, keep it to a single line. Explanatory context belongs in this file or in the commit message.
