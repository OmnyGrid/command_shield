import '../analysis/command_analysis.dart';
import '../security/security_level.dart';
import '../validation/command_decision.dart';
import '../validation/command_result.dart';
import 'command_policy.dart';

/// Flags commands that expand environment variables (`$HOME`, `${HOME}`,
/// `%USERPROFILE%`, `$env:USERPROFILE`).
///
/// It relies on the `env-expansion` security findings. By default expansion
/// yields [CommandDecision.review]; set [onMatch] to deny for a strict policy.
class EnvironmentVariableExpansionPolicy extends CommandPolicy {
  /// Creates the policy.
  const EnvironmentVariableExpansionPolicy({
    this.onMatch = CommandDecision.review,
    this.level = SecurityLevel.lowRisk,
  });

  /// The decision returned when expansion is detected.
  final CommandDecision onMatch;

  /// The severity attached to the finding.
  final SecurityLevel level;

  @override
  String get name => 'environment-variable-expansion';

  @override
  CommandResult evaluate(CommandAnalysis analysis) {
    final relevant = analysis.findings
        .where((f) => f.code == 'env-expansion')
        .toList();
    if (relevant.isEmpty) return allowResult;
    return result(onMatch, level, relevant.first.message);
  }
}
