# Threat model & security rationale

`command_shield` is a **pre-execution analysis layer**. It answers “should this
command be allowed to run?” with an explainable ALLOW / REVIEW / DENY verdict.
This document states what it defends against, what it does not, and why.

## Goals

1. **Catch obviously dangerous commands** before they execute
   (`rm -rf /`, `curl … | bash`, `sudo`, inline shell execution, …).
2. **Make intent explicit and reviewable** — capabilities, effects, and
   findings let a human or agent reason about a command.
3. **Be deterministic and explainable** — identical input yields identical,
   justified output suitable for audit logs and policy gates.
4. **Be safe to embed anywhere** — pure Dart, no execution, no IO, no platform
   channels; runs on Flutter Web.

## Non-goals (explicit limitations)

`command_shield` is **not** a sandbox and **cannot** guarantee safety.

- **It does not execute, resolve, or expand anything.** It cannot know the
  runtime value of `$VAR`, the contents of a script file, what a URL serves, or
  the current working directory.
- **It is heuristic.** Detection is based on patterns and a knowledge base.
  Unknown tools produce no capabilities; novel attacks may go unflagged.
- **It can be evaded by obfuscation.** Base64/`-EncodedCommand` payloads,
  string concatenation, indirection via variables, unusual quoting, aliases,
  symlinks, and creative encodings can hide intent from static analysis.
- **`safe` is not a guarantee.** A command flagged `safe` may still be harmful
  in a particular context (e.g. reading a sensitive file your policy forbids).
- **It is conservative**, which means **false positives** are expected. Tune the
  policies and knowledge base to your environment.

## Adversary model

| Adversary                                   | Coverage                                   |
| ------------------------------------------- | ------------------------------------------ |
| Careless/buggy command (typos, wrong path)  | **Good** — catches catastrophic patterns   |
| Non-expert misuse via an AI agent           | **Good** — explainable gating + review     |
| Casual malicious one-liners                 | **Partial** — common patterns detected     |
| Determined attacker using obfuscation       | **Weak** — static analysis is bypassable   |
| Compromised executable / supply chain       | **None** — out of scope                    |

## How detection works (and where it breaks)

- Parsing strips quotes and tracks substitutions/env references, so quoted
  metacharacters do not cause false positives — but a value only known at
  runtime (`$CMD`) is opaque.
- The destructive detector looks *through* wrapper commands (`sudo rm -rf /` is
  still critical) and inspects flags/targets — but it cannot evaluate globs or
  variables, so `rm -rf "$DIR"` is judged by the literal `$DIR`.
- Remote-exec detection matches a downloader piped into a shell, structurally
  and via a raw-text fallback — but `eval "$(curl …)"` or fetch-then-run across
  two statements may evade the simple pattern.

## Required compensating controls

Use `command_shield` as **one defence-in-depth layer**, never the only one.
Combine it with real isolation:

- **Sandboxing** (seccomp, AppArmor, SELinux, gVisor, WASM, etc.)
- **Containers / VMs** with minimal images and no host mounts
- **Least privilege** (drop root, restricted users, capability sets)
- **Process isolation** and resource limits (cgroups, ulimits, timeouts)
- **Network egress controls** (deny by default)
- **Human review** for any `REVIEW` verdict; fail closed on `DENY`

## Responsible use

Treat `DENY` as a hard stop and `REVIEW` as “require explicit human/secondary
approval”. Log the full `CommandAnalysis` (capabilities, effects, findings,
level) for auditability. Re-validate after any normalization or templating your
own system performs, since that can change a command’s meaning.
