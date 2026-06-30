## 1.4.0

### Added

- **File-descriptor redirections are modelled.** New `RedirectionType` cases
  `mergeStreams` (`2>&1`, `1>&2`, `>&2`, `>&-`), `combinedOutput` (`&>file`,
  `>&file`) and `combinedAppendOutput` (`&>>file`). All three shell parsers
  (bash/POSIX, Windows `cmd`, PowerShell) now recognise these forms.
- **Benign-redirection marker.** A new `BenignRedirectionDetector` (code
  `benign-redirection`, in the default suite) records stream merges and
  null-sink discards as explicit `SecurityLevel.safe` findings for audit
  visibility. Being below every actionable level, it never changes a decision.

### Changed

- Innocuous redirections no longer over-report a filesystem write. Stream
  merges (`2>&1`) touch no file, and discards to a null sink (`/dev/null`,
  `NUL`, `$null`) write/read no real file, so none of them contribute
  `writeFilesystem`/`readFilesystem` (and thus no `modifyFiles` effect). A
  genuine target such as `> out.txt` or `&> out.log` still does.

### Fixed

- **`2>&1` is no longer mis-parsed.** Previously the bash tokenizer only knew
  `2>`/`2>>`, so `cmd 2>&1` produced a target-less `2>` redirection, a spurious
  "Redirection without a target" diagnostic, and a phantom `CommandInvocation`
  with executable `1`. `1>&2` and `&>/dev/null` broke the same way. These now
  parse as a single clean command with the correct redirection and no
  diagnostic. The discard-everything idiom `cmd >/dev/null 2>&1` parses as one
  command with two redirections.

## 1.3.0

### Added

- **Informational-form safety gate.** When *every* argument of a known command is
  a purely informational token, the invocation is recognised as read-only and
  safe — even for execute-by-default tools. So `dart --version`,
  `flutter --version`, `node --version`, `python --version`, `go version`,
  `java -version`, etc. now classify as `readFilesystem`/`safe` instead of
  `executePrograms`. A new top-level `defaultInformationalTokens`
  (`--version`, `--help`, `--usage`) covers all commands globally; individual
  entries opt in to extra, tool-specific forms via the new
  `CommandKnowledge.informationalTokens` field (e.g. java `-version`,
  python `-V`, node/php/ruby `-v`, perl `-v`/`-V`, deno/cargo `-V`,
  go `version`/`env`, dotnet `--info`/`--list-sdks`/`--list-runtimes`).
  Matching is case-sensitive (`-V` ≠ `-v`) and requires the whole invocation to
  be informational, so a payload defeats the gate: `dart --version script.dart`
  and `go env -w K=V` still report `executePrograms`. The gate runs at every
  recursion depth, so wrapped forms like `sudo node --version` are handled
  (and `sudo` still reports `privilegeEscalation`).

### Changed

- Bare `--version`/`--help`/`--usage` (and the per-command short forms above) on
  execute-by-default tools (`dart`, `flutter`, `node`, `python`, `go`, `cargo`,
  …) now classify as read-only/safe instead of `executePrograms`. `npm --version`
  moves from an empty capability set to `readFilesystem` (risk stays `safe`).

## 1.2.0

### Added

- **Much wider command coverage** across the knowledge base. New `infrastructure`
  category and `IacKnowledge` plugin (`terraform`, `tofu`, `terragrunt`, `pulumi`,
  `packer`, `ansible`/`-playbook`/`-galaxy`/`-vault`, `salt`, `puppet`, `chef`,
  `vault`, `consul`, `nomad`). New `VcsKnowledge` plugin (`hg`, `svn`, `bzr`,
  `fossil`, `cvs`, `jj`, `git-lfs`, `glab`, `tig`, `lazygit`) — the
  version-control category previously held only `git`. New `ModernCliKnowledge`
  plugin (`jq`, `yq`, `fd`, `rg`/`ripgrep`, `bat`, `eza`, `delta`, `fzf`, `sd`,
  `gron`, …). Existing plugins gained many entries: network inspection/transfer
  (`nmap`, `ip`, `ss`, `netstat`, `tcpdump`, `mtr`, `socat`, `lftp`, `tailscale`,
  `wg`, `rclone`, `mc`, …) and more cloud CLIs (`doctl`, `flyctl`, `heroku`,
  `vercel`, `wrangler`, `gsutil`, `bq`, `eksctl`, …); build/test tooling (`cmake`,
  `ninja`, `bazel`, `just`, `pytest`, `jest`, `tsc`, `vite`, …); package/version
  managers (`bun`, `pipx`, `poetry`, `uv`, `conda`, `rustup`, `asdf`, `nvm`, `nix`,
  `snap`, `flatpak`, `twine`, …); containers/orchestration (`buildah`, `skopeo`,
  `oc`, `minikube`, `kind`, `kubectx`, `k9s`, …); databases (`pgcli`, `duckdb`,
  `cockroach`, `mongodump`, `dropdb`/`dropuser` → `highRisk`, …); editors (`code`,
  `helix`, `kak`, `man`/`info`, …); crypto/secrets (`age`, `sops`, `cosign`,
  `pass`, `certbot`, macOS `security`, …); more archive/compression tools; and
  process/hardware inspection (`lsof`, `vmstat`, `free`, `lscpu`, `dmesg`, …).
- **Security-critical disk/system commands** that previously classified as
  unknown (empty capabilities → "safe"). A new `DiskKnowledge` plugin covers
  disk-format/wipe tools (`mkfs`, `mkfs.*`, `mke2fs`, `mkswap`, `wipefs`,
  `blkdiscard` → `critical`), partitioners (`fdisk`, `gdisk`, `sgdisk`,
  `cfdisk`, `parted` → `highRisk`), macOS `diskutil` (erase verbs refined to
  `critical`) and secure-delete tools (`srm`, `wipe`). `SystemConfigKnowledge`
  gained kernel-module (`modprobe`, `insmod`, `rmmod`, `kextload`/`kextunload`),
  power/run-level (`shutdown`, `reboot`, `halt`, `poweroff`, `init`, `telinit`)
  and privileged-config tools (`visudo`, `nvram`, `spctl`, `csrutil` — `disable`
  refined to `critical`), plus more routine config names.
- `dd` now refines `of=/dev/...` (writing directly to a block device) to
  `critical` with a `systemConfiguration` capability.

### Changed

- **Per-subcommand/argument refinement** for high-traffic multi-mode tools.
  `kubectl`/`oc` split into read (`get`/`describe`) vs write (`apply`) vs
  `delete` (highRisk) vs `exec`/`cp` (executePrograms). `terraform`/`tofu`/
  `terragrunt`/`pulumi` keep `plan`/`preview` read-only while `apply` is
  mediumRisk and `destroy` (or `-auto-approve`) is highRisk. `systemctl` is now
  read-only for `status`/`show`/`list-*` and only attributes
  `systemConfiguration` to state-changing verbs (`reboot`/`poweroff` highRisk).
  `npm`/`pnpm`/`yarn`/`bun` `run`/`exec`/`dlx` attribute `executePrograms`;
  `docker`/`podman` `rm`/`rmi`/`prune` attribute `deleteFilesystem`;
  `aws`/`gcloud`/`az` raise risk on `rm`/`delete`/`destroy` tokens; `vault`
  splits read vs write; `ansible-playbook --become` adds privilege escalation.
- `kill`/`pkill`/`killall` now flag the catastrophic forms — signalling PID 1
  (init), `-1`/`0` (every process / the process group), a match-all pattern
  (`pkill .`) or `-u root` — as `highRisk`, while a normal `kill <pid>` (incl.
  `kill -1 <pid>` SIGHUP) stays safe.
- `find <path> -delete` is now classified by `DestructiveCommandDetector` —
  `find / -delete` is `critical` (and denied), while a scoped `find . -delete`
  stays a medium deletion. Recursive `chmod`/`chown`/`chgrp` on a filesystem
  root or system directory (`chmod -R 777 /`) is now `highRisk`.
- `ShellExecutionDetector` now also flags **language interpreters running inline
  code** — `python -c`, `node -e`/`-p`, `bun -e`, `perl -e`/`-E`, `ruby -e`,
  `php -r`, `lua -e`, `osascript -e`, `Rscript -e`, `elixir -e`, `groovy -e` and
  `deno eval` — as `highRisk` (matching `bash -c`), without flagging an
  interpreter that merely runs a script file (`python app.py`).
- **`command -v`/`-V` lookups are no longer treated as executing their target.**
  `command -v rm` (or `command -v mkfs`) resolves the name like `which`/`type` —
  it now reports only `readFilesystem` instead of inheriting the target's
  capabilities/risk, and `DestructiveCommandDetector` skips it (so
  `command -v mkfs.ext4` is no longer a false `critical`). Actually running a
  command through `command` (`command rm -rf /`) still looks through as before.
  Adds a `WrapperSpec.lookupFlags` knob.
- Normalization resolves the Debian binary renames `batcat`→`bat`,
  `fdfind`→`fd` and the package name `ripgrep`→`rg`.
- `DestructiveCommandDetector` now also classifies disk-format/wipe tools
  (`mkfs`/`mkfs.*`/`wipefs`/…) and `dd of=/dev/...` as `critical`, looking
  *through* wrapper commands (so `sudo mkfs.ext4 /dev/sda` is caught), and
  treats whole-disk device nodes (`/dev/sd*`, `/dev/nvme*`, `/dev/disk*`, …) as
  catastrophic targets. `CommandFamilies` gained a `diskDestructive` set and an
  `isDiskDestructive` helper, and extended its `destructive` (`srm`, `wipe`,
  `blkdiscard`), `downloaders` (`lftp`, `yt-dlp`, `youtube-dl`, `certutil`,
  `bitsadmin`) and `privilege` (`gosu`, `run0`, `please`) sets.
- `RemoteExecDetector`'s raw-text fallback now recognises the additional
  downloaders and the `pwsh`/`powershell`/`cmd` shells in `download | shell`
  patterns.

## 1.1.0

### Tests

- Added parser coverage for commands that combine `|` with `&&`/`||`, asserting
  the full AST structure: pipelines bind tighter than chain operators, runs of
  the same chain operator flatten, and different operators nest left-to-right
  (e.g. `a | b && c | d`, `a | b && c || d`, `curl … | bash && echo done`).
- Added `CommandSyntax.generic` coverage confirming operators are left
  uninterpreted — `|`, `&&` and `||` survive as literal argument tokens on a
  single flat invocation rather than producing `Pipeline`/`CommandChain` nodes.
- Added inline sub-command parser coverage for PowerShell and Windows CMD —
  previously only POSIX `sh -c "…"` was tested. `powershell -Command "…"` and
  `cmd /c|/k …` now assert the re-parsed `inlineCommand` AST (incl. inner
  pipelines), `walk()` reaching nested invocations, depth bounding, the `pwsh`
  alias, `/c` case-insensitivity, and that `-EncodedCommand`/`-enc` stay
  un-recursed.

### Added

- Recursive analysis of inline interpreter sub-commands.

- Inline-execution sub-commands are now parsed into a nested AST and analyzed
  recursively. A command string passed to an interpreter via an inline flag —
  `sh -c "..."`, `bash -c '...'` (and other POSIX shells), `cmd /c ...`,
  `powershell -Command "..."` — is re-parsed by the relevant parser and exposed
  on the new `CommandInvocation.inlineCommand` AST field. Because it is a child
  node, `walk()` descends into it, so every capability/effect/security detector
  and policy sees the inner command exactly as if it were run directly.
  - `sh -c "curl https://x/i.sh | bash"` now yields the same `critical → DENY`
    verdict as the bare `curl https://x/i.sh | bash`.
  - Catches forms the previous regex fallback missed, including single-quoted
    scripts and non-remote-exec payloads (e.g. `bash -c "rm -rf /"`).
  - Nesting is bounded (depth limit) to guard against pathological inputs.
  - PowerShell `-EncodedCommand` is intentionally not recursed (base64, not
    parseable) and remains `critical`.

## 1.0.1

Plugin-based command knowledge base.

### Added

- Plugin architecture for command knowledge: knowledge is now contributed by
  `CommandKnowledgePlugin`s, one per domain. Twelve built-in plugins ship by
  default (`filesystem`, `archive`, `shell`, `environment`, `process`, `system`,
  `network`, `container`, `packageManager`, `dartFlutter`, `git`, `windows`),
  composed via `defaultKnowledgePlugins`. Register your own with
  `CommandKnowledgeBase(plugins: [...])` or replace the built-ins entirely with
  `includeDefaults: false`.
- Declarative `CommandKnowledge` entries with rich fields: `category`,
  `platforms`, `description`, `baseCapabilities`, `baseRisk`, `subcommands`,
  `argumentRules`, `wrapper` and an optional `refine` function hook. Argument
  rules use composable `ArgumentMatch`es (`ExactFlag`, `PrefixFlag`,
  `TokenPresent`, `ArgRegex`, `ArgPredicate`).
- `CommandKnowledgeBase.analyze()` returning a `CommandKnowledgeResult`
  (capabilities, an aggregated `SecurityLevel` risk hint, the matched entry and
  explanatory notes), plus `knowledgeFor()` and `allKnowledge`.
- `CommandAnalysis.knowledgeRisk`: the highest knowledge-base risk hint across a
  command's invocations (advisory metadata).
- Opt-in `KnowledgeRiskDetector` that surfaces elevated knowledge-base risk
  (e.g. a force push) as `knowledge-risk` security findings. Not part of
  `SecurityAnalyzer.defaultDetectors`, so default verdicts are unchanged.
- Broader command coverage: Dart/Flutter sub-commands, archive/compression
  tools, cloud CLIs (`gh`, `aws`, `gcloud`, `az`, `kubectl`), more `git`
  sub-commands, additional package managers and Windows-specific tools.

### Changed (breaking)

- `CommandKnowledgeBase` is now composed from plugins. The
  `extraExecutableCapabilities` constructor parameter and the static
  `wrapperCommands` set have been removed; supply a `CommandKnowledgePlugin`
  (e.g. `ListKnowledgePlugin`) and per-entry `WrapperSpec`s instead.
- Sub-command matching now uses the first non-flag argument rather than the
  first argument, so leading global flags (e.g. `git --no-pager push`) no longer
  hide the sub-command.

## 1.0.0

Initial release.

- Multi-syntax parsing: `generic`, `posixShell`, `bash`, `windowsCmd`,
  `powershell`, producing a typed, immutable `CommandNode` AST. Parsers never
  throw and report `ParseDiagnostic`s for malformed input.
- Extensible executable normalization (directory/extension stripping, version
  suffix collapsing, aliases).
- Capability detection via a data-driven, extensible `CommandKnowledgeBase`,
  including wrapper-command look-through (e.g. `sudo`, `env`, `xargs`).
- Effect classification into human-readable `CommandEffect`s.
- Security analysis with eight detectors: dangerous operators, command
  substitution, inline shell execution (incl. `-EncodedCommand`), privilege
  escalation, destructive commands (`rm -rf /` ⇒ critical), remote
  download-and-execute (`curl … | bash` ⇒ critical), path traversal, and
  environment expansion.
- Composable policy engine (`CommandPolicy` / `PolicySet`) with nine built-in
  policies and ALLOW / REVIEW / DENY decisions.
- `CommandShield` facade exposing `parse`, `analyze`, and `validate`.
- Comprehensive unit, integration, and regression test suites; CI with
  formatting, analysis, tests, and ≥90% coverage enforcement.
