## 1.1.1

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

## 1.1.0

Recursive analysis of inline interpreter sub-commands.

### Added

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
