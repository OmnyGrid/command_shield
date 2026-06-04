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
