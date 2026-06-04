import 'package:meta/meta.dart' show immutable;

import '../security/security_finding.dart';
import '../security/security_level.dart';
import 'command_decision.dart';

/// The outcome of validating a command against a policy.
@immutable
final class CommandResult {
  /// Creates a command result.
  const CommandResult({
    required this.decision,
    required this.securityLevel,
    required this.findings,
  });

  /// A convenience constructor for an allow result with no findings.
  const CommandResult.allow({
    this.securityLevel = SecurityLevel.safe,
    this.findings = const <SecurityFinding>[],
  }) : decision = CommandDecision.allow;

  /// The final verdict.
  final CommandDecision decision;

  /// The security severity associated with the verdict.
  final SecurityLevel securityLevel;

  /// The findings that justify the verdict, in severity order.
  final List<SecurityFinding> findings;

  /// Whether the command was allowed.
  bool get isAllowed => decision == CommandDecision.allow;

  /// Combines this result with [other] by taking the most restrictive
  /// [decision], the maximum [securityLevel] and the union of [findings]
  /// (de-duplicated, preserving order).
  CommandResult merge(CommandResult other) {
    final merged = <SecurityFinding>[...findings];
    for (final f in other.findings) {
      if (!merged.contains(f)) merged.add(f);
    }
    return CommandResult(
      decision: decision.mostRestrictive(other.decision),
      securityLevel: securityLevel.max(other.securityLevel),
      findings: List<SecurityFinding>.unmodifiable(merged),
    );
  }

  @override
  String toString() =>
      'CommandResult(${decision.name}, level: ${securityLevel.name}, '
      'findings: ${findings.length})';
}
