import '../analysis/command_analysis.dart';
import '../security/security_level.dart';
import '../validation/command_decision.dart';
import '../validation/command_result.dart';
import 'command_policy.dart';

/// Permits only commands whose every (normalized) executable is on an explicit
/// allow-list. Any other executable yields [onViolation] (default
/// [CommandDecision.deny]).
///
/// Matching is case-insensitive and uses the normalized executable names, so
/// `/bin/ls` and `ls` are treated identically.
class ExecutableAllowListPolicy extends CommandPolicy {
  /// Creates the policy from the set of [allowed] executables.
  ExecutableAllowListPolicy(
    Set<String> allowed, {
    this.onViolation = CommandDecision.deny,
    this.level = SecurityLevel.highRisk,
  }) : allowed = allowed.map((e) => e.toLowerCase()).toSet();

  /// The lower-cased set of permitted executable names.
  final Set<String> allowed;

  /// The decision returned when a disallowed executable is present.
  final CommandDecision onViolation;

  /// The severity attached to the finding.
  final SecurityLevel level;

  @override
  String get name => 'executable-allow-list';

  @override
  CommandResult evaluate(CommandAnalysis analysis) {
    if (analysis.normalizedExecutables.isEmpty) return allowResult;
    final disallowed =
        analysis.normalizedExecutables
            .where((e) => !allowed.contains(e.toLowerCase()))
            .toSet()
            .toList()
          ..sort();
    if (disallowed.isEmpty) return allowResult;
    return result(
      onViolation,
      level,
      'Executable(s) not on the allow-list: '
      '${disallowed.map((e) => '"$e"').join(', ')}.',
    );
  }
}
