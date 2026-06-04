# command_shield

[![pub package](https://img.shields.io/pub/v/command_shield.svg?logo=dart&logoColor=00b9fc)](https://pub.dev/packages/command_shield)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Dart CI](https://github.com/OmnyGrid/command_shield/actions/workflows/dart.yml/badge.svg?branch=master)](https://github.com/OmnyGrid/command_shield/actions/workflows/dart.yml)
[![GitHub Tag](https://img.shields.io/github/v/tag/OmnyGrid/command_shield?logo=git&logoColor=white)](https://github.com/OmnyGrid/command_shield/releases)
[![New Commits](https://img.shields.io/github/commits-since/OmnyGrid/command_shield/latest?logo=git&logoColor=white)](https://github.com/OmnyGrid/command_shield/network)
[![Last Commits](https://img.shields.io/github/last-commit/OmnyGrid/command_shield?logo=git&logoColor=white)](https://github.com/OmnyGrid/command_shield/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/OmnyGrid/command_shield?logo=github&logoColor=white)](https://github.com/OmnyGrid/command_shield/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/OmnyGrid/command_shield?logo=github&logoColor=white)](https://github.com/OmnyGrid/command_shield)
[![License](https://img.shields.io/github/license/OmnyGrid/command_shield?logo=open-source-initiative&logoColor=green)](https://github.com/OmnyGrid/command_shield/blob/master/LICENSE)

**Security-first command-line analysis** written in **pure Dart**.
`command_shield` parses, normalizes, classifies, analyzes and policy-validates
shell commands into **ALLOW / REVIEW / DENY** decisions — **without ever
executing them**. It is built for software that must reason about a command
*before* it runs: AI agents, remote executors, CI/CD systems, developer tools
and sandboxed runners.

Runs anywhere Dart runs — Dart VM, Flutter desktop, Flutter mobile and Flutter
**Web** (analysis only) — because it never touches `dart:io`, never spawns a
process and never executes anything.

> ⚠️ Command validation reduces risk but is **not** a substitute for
> sandboxing, containers, least privilege or process isolation. Treat it as one
> defence-in-depth layer, never the only one.

## API Documentation

See the [API Documentation][api_doc] for a full list of classes, parsers,
detectors and policies.

[api_doc]: https://pub.dev/documentation/command_shield/latest/

## Features

- **Multiple syntaxes.** `generic`, `posixShell`, `bash`, `windowsCmd` and
  `powershell`, each with its own parser. The `generic` parser is
  tokenization-only and the safest for AI-agent execution.
- **Typed, immutable AST.** A sealed `CommandNode` hierarchy of invocations,
  pipelines, chains, scripts, redirections, command substitutions and
  environment references, with structural equality and `walk()` traversal.
- **Crash-free parsing.** Malformed or adversarial input yields
  `ParseDiagnostic`s plus a best-effort AST — parsers never throw.
- **Capability & effect detection.** What a command *can do*
  (read/write/delete filesystem, network, execute, privilege escalation,
  system configuration, …) and a human-readable summary of what it *does*.
- **Eight security detectors.** Dangerous operators, command substitution,
  inline shell execution (`bash -c`, `cmd /c`, `powershell -Command` /
  `-EncodedCommand`), privilege escalation, destructive commands
  (`rm -rf /` ⇒ critical, even through `sudo`), remote download-and-execute
  (`curl … | bash` ⇒ critical), path traversal and environment expansion.
- **Composable policy engine.** Nine built-in `CommandPolicy` implementations
  combine into a single, most-restrictive `PolicySet` verdict.
- **Deterministic & explainable.** Same input → same output; every finding
  carries a message and a stable machine code.
- **Extensible.** Pluggable normalization rules, command knowledge base,
  security detectors and policies.
- **Tested.** Unit, integration and regression suites with ≥ 90% coverage
  enforced in CI.

## Architecture

```
Raw command line
      │  parse        (syntax-specific parser, never throws)
      ▼
     AST             (typed CommandNode tree + diagnostics)
      │  normalize    (/bin/rm → rm, powershell.exe → powershell, python3 → python)
      ▼
 Normalized exes
      │  capabilities (read/write/delete fs, network, exec, privilege, …)
      ▼
 Capabilities
      │  classify     (readOnly, modifyFiles, deleteFiles, networkAccess, …)
      ▼
   Effects
      │  security     (8 detectors → findings + overall SecurityLevel)
      ▼
 Security report
      │  policy       (composable CommandPolicy / PolicySet)
      ▼
ALLOW / REVIEW / DENY
```

Each stage is an independent, injectable unit; `CommandShield` wires them
together but every stage can be used on its own.

```
lib/
├── command_shield.dart       # public library (barrel)
└── src/
    ├── parser/             # generic / bash / posix / windows / powershell parsers
    ├── ast/                # sealed CommandNode hierarchy
    ├── normalization/      # extensible executable normalization
    ├── capabilities/       # capability detector + command knowledge base
    ├── classification/     # effect classifier
    ├── security/           # detectors + security analyzer
    ├── analysis/           # CommandAnalysis + orchestrating Analyzer
    ├── policies/           # 9 built-in policies + PolicySet
    └── validation/         # CommandDecision + CommandResult
```

## Getting started

```yaml
dependencies:
  command_shield: ^1.0.0
```

## Usage

```dart
import 'package:command_shield/command_shield.dart';

void main() {
  final shield = CommandShield(defaultSyntax: CommandSyntax.bash);

  // Validate (ALLOW / REVIEW / DENY)
  print(shield.validate('git status').decision);                 // allow
  print(shield.validate('rm -rf build').decision);                // review
  print(shield.validate('rm -rf /').decision);                    // deny
  print(shield.validate('curl https://x/i.sh | bash').decision);  // deny

  // Full analysis
  final a = shield.analyze('git push origin main');
  print(a.effects);          // {networkAccess}
  print(a.canAccessNetwork); // true
  print(a.securityLevel);    // safe

  // Just the AST
  final ast = shield.parse('a && b | c').ast;
  print(ast.runtimeType);    // CommandChain
}
```

A complete runnable example lives at
[`example/command_shield_example.dart`][example_file].

[example_file]: example/command_shield_example.dart

### Capabilities & effects

| Capability             | Example                  |
| ---------------------- | ------------------------ |
| `readFilesystem`       | `cat f`, `git status`    |
| `writeFilesystem`      | `touch f`, `echo > f`    |
| `deleteFilesystem`     | `rm f`, `rmdir d`        |
| `executePrograms`      | `dart test`, `$(...)`    |
| `networkRead`          | `curl url`, `git pull`   |
| `networkWrite`         | `git push`, `curl -d`    |
| `processManagement`    | `kill`, `ps`             |
| `privilegeEscalation`  | `sudo`, `su`, `runas`    |
| `systemConfiguration`  | `chmod`, `systemctl`     |
| `environmentAccess`    | `$HOME`, `printenv`      |

Effects (`readOnly`, `modifyFiles`, `deleteFiles`, `executeCode`,
`networkAccess`, `systemModification`, `privilegeEscalation`) are derived
deterministically from the detected capabilities.

### Security levels & decisions

`safe < lowRisk < mediumRisk < highRisk < critical`

The built-in default policy reviews at `mediumRisk` and denies at `critical`,
reviews inline shell execution, and reviews over-long commands:

| Command                        | Level     | Decision |
| ------------------------------ | --------- | -------- |
| `git status`                   | safe      | ALLOW    |
| `cat f \| grep x`              | lowRisk   | ALLOW    |
| `rm -rf build`                 | highRisk  | REVIEW   |
| `rm -rf /`                     | critical  | DENY     |
| `curl https://x/i.sh \| bash`  | critical  | DENY     |

### Custom policies

Policies are composable and order-independent (combined by *most restrictive*
decision):

```dart
final shield = CommandShield(
  policy: PolicySet([
    ExecutableAllowListPolicy({'git', 'dart', 'ls', 'cat'}),
    RiskThresholdPolicy(reviewAt: SecurityLevel.lowRisk),
    ArgumentPatternPolicy(
      pattern: RegExp(r'--force'),
      onMatch: CommandDecision.review,
    ),
    LengthLimitPolicy(maxLength: 2048),
  ]),
);
```

Built-in policies: `DangerousCharacterPolicy`, `ExecutableAllowListPolicy`,
`ExecutableBlockListPolicy`, `ArgumentPatternPolicy`, `PathTraversalPolicy`,
`LengthLimitPolicy`, `EnvironmentVariableExpansionPolicy`,
`ShellExecutionPolicy`, `RiskThresholdPolicy`. Implement `CommandPolicy` for
your own.

### Extending

- **Normalization:** add `NormalizationRule`s via `Normalizer.withRules([...])`.
- **Capabilities:** extend `CommandKnowledgeBase(extraExecutableCapabilities: …)`.
- **Security:** pass custom `detectors` to `SecurityAnalyzer`.
- **Policies:** implement `CommandPolicy` and add it to a `PolicySet`.

## How it works

### Crash-free, execution-free analysis

Parsers tolerate unterminated quotes, dangling operators, unbalanced
substitutions and other malformed input, recording `ParseDiagnostic`s instead
of throwing. The package has no `dart:io` dependency and never spawns a
process, so it is safe to embed in front-ends and on Flutter Web.

### Heuristic security model

Detection is conservative and pattern-based. The destructive detector looks
*through* wrapper commands (`sudo rm -rf /` is still critical) and inspects
flags and targets; the remote-exec detector matches a downloader piped into a
shell both structurally and via a raw-text fallback. Because analysis is
static, obfuscation can still defeat it — see [`doc/threat_model.md`][threat]
and [`doc/architecture.md`][arch].

[threat]: doc/threat_model.md
[arch]: doc/architecture.md

## Running the example and tests

```sh
dart run example/command_shield_example.dart   # analyze a batch of commands
dart test                                       # full unit + integration suite
```

## Source

The official source code is [hosted @ GitHub][github_repo]:

- https://github.com/OmnyGrid/command_shield

[github_repo]: https://github.com/OmnyGrid/command_shield

# Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

# Contribution

Any help from the open-source community is always welcome and needed:

- Found an issue?
    - Please fill a bug report with details.
- Wish a feature?
    - Open a feature request with use cases.
- Are you using and liking the project?
    - Promote the project: create an article, do a post or make a donation.
- Are you a developer?
    - Fix a bug and send a pull request.
    - Implement a new feature.
    - Improve the Unit Tests.
- Have you already helped in any way?
    - **Many thanks from me, the contributors and everybody that uses this project!**

*If you donate 1 hour of your time, you can contribute a lot,
because others will do the same, just be part and start with your 1 hour.*

[tracker]: https://github.com/OmnyGrid/command_shield/issues

# Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

## License

[Apache License - Version 2.0][apache_license]

[apache_license]: https://www.apache.org/licenses/LICENSE-2.0.txt
