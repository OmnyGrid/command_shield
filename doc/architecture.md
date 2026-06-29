# Architecture

`command_shield` is a staged pipeline. Each stage is an independent, immutable,
deterministic unit with a single responsibility, wired together by the
`CommandShield` facade. Any stage can be used or replaced on its own.

```text
parse → normalize → capabilities → effects → security → policy → decision
```

## 1. Parse (`src/parser/`)

A `CommandParser` turns a raw string into a `ParseResult` (a best-effort
`CommandNode` AST plus `ParseDiagnostic`s). Parsers **never throw** and **never
execute**; adversarial or malformed input degrades to diagnostics and a partial
tree.

| Syntax        | Parser               | Interprets                                         |
| ------------- | -------------------- | ------------------------------------------------- |
| `generic`     | `GenericParser`      | tokenization only (safest) — no operators         |
| `posixShell`  | `PosixParser`        | pipelines, chains, redirs, subst, env, scripts    |
| `bash`        | `BashParser`         | same as POSIX (bash-family superset)              |
| `windowsCmd`  | `WindowsCmdParser`   | `&`/`&&`/`||`, `|`, redirs, `%VAR%`               |
| `powershell`  | `PowerShellParser`   | `|`, `;`, `&&`/`||`, `$(...)`, `$env:VAR`, `$VAR` |

`ParserFactory.forSyntax` resolves the (stateless, `const`) parser.

### AST (`src/ast/command_node.dart`)

A `sealed class CommandNode` hierarchy enables exhaustive switches:
`CommandInvocation`, `Pipeline`, `CommandChain` (+ `ChainOperator`),
`CommandScript`, `RedirectionNode` (+ `RedirectionType`), `CommandSubstitution`,
`EnvironmentVariableReference`. All nodes are immutable with structural equality
and a `walk()` depth-first traversal.

## 2. Normalize (`src/normalization/`)

`Normalizer` applies an ordered, extensible list of `NormalizationRule`s to map
executables to a canonical form: strip directory (`/bin/rm` → `rm`), strip
Windows extension (`powershell.exe` → `powershell`), collapse version suffixes
(`python3` → `python`), resolve aliases (`pwsh` → `powershell`). Add rules with
`Normalizer.withRules`.

## 3. Capabilities (`src/capabilities/`)

`CapabilityDetector` walks the AST and consults a data-driven
`CommandKnowledgeBase` to produce a `Set<CommandCapability>`. It understands
sub-commands (`git push` → networkWrite vs `git status` → readFilesystem),
upload flags, and **wrapper commands** (`sudo`, `env`, `xargs`, …) whose wrapped
program's capabilities are attributed to the invocation. Structural features add
capabilities too: redirections imply read/write, substitutions imply execution,
env references imply environment access. Conversely, purely informational
invocations — where every argument is a version/help token such as
`dart --version`, `node --version` or `--help` — are recognised and treated as
read-only even for execute-by-default tools.

## 4. Effects (`src/classification/`)

`EffectClassifier` maps capabilities to coarse, human-readable `CommandEffect`s.
`readOnly` is reported only when no mutating/executing/network/privilege effect
exists.

## 5. Security (`src/security/`)

`SecurityAnalyzer` runs an extensible list of `SecurityDetector`s over a shared
`SecurityContext` (raw, AST, normalizer, plus quote-stripped views) and
aggregates `SecurityFinding`s, computing the overall `SecurityLevel` as the
maximum finding level. Findings are sorted deterministically.

Built-in detectors: dangerous operators, command substitution, shell execution
(`bash -c`, `cmd /c`, `powershell -Command`/`-EncodedCommand`), privilege
escalation, destructive commands (incl. `rm -rf /` ⇒ critical, looking through
wrappers), remote download-and-execute (`curl … | bash` ⇒ critical), path
traversal, and environment expansion.

## 6. Policy (`src/policies/`, `src/validation/`)

A `CommandPolicy` turns a `CommandAnalysis` into a `CommandResult`
(`CommandDecision` + level + findings). `PolicySet` composes policies by taking
the **most restrictive** decision and the union of findings, so order does not
matter. The default policy (`buildDefaultPolicy`) reviews at `mediumRisk`, denies
at `critical`, reviews inline shell execution, and reviews over-long commands.

## Orchestration

`Analyzer` runs stages 2–5 over a `ParseResult` to produce a `CommandAnalysis`.
`CommandShield` exposes the three public operations:

- `parse` → `ParseResult`
- `analyze` → `CommandAnalysis`
- `validate` → `CommandResult`

All collaborators (`Normalizer`, `CapabilityDetector`, `EffectClassifier`,
`SecurityAnalyzer`, `CommandPolicy`, `Analyzer`) are injectable for
customization and testing.

## Design invariants

- **No execution, no IO, no platform APIs** — safe on Flutter Web.
- **Deterministic** — no clock, randomness, or environment reads.
- **Crash-free** — parsing/analysis never throw on any input.
- **Explainable** — every finding has a message and a stable `code`.
- **Immutable models** — `final` classes with value equality.
