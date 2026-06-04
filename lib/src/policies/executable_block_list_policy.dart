import '../analysis/command_analysis.dart';
import '../security/security_level.dart';
import '../validation/command_decision.dart';
import '../validation/command_result.dart';
import 'command_policy.dart';

/// Rejects commands that invoke any executable on a block-list.
///
/// Matching is case-insensitive and uses normalized executable names.
class ExecutableBlockListPolicy extends CommandPolicy {
  /// Creates the policy from the set of [blocked] executables.
  ExecutableBlockListPolicy(
    Set<String> blocked, {
    this.onMatch = CommandDecision.deny,
    this.level = SecurityLevel.highRisk,
  }) : blocked = blocked.map((e) => e.toLowerCase()).toSet();

  /// The lower-cased set of blocked executable names.
  final Set<String> blocked;

  /// The decision returned when a blocked executable is present.
  final CommandDecision onMatch;

  /// The severity attached to the finding.
  final SecurityLevel level;

  @override
  String get name => 'executable-block-list';

  @override
  CommandResult evaluate(CommandAnalysis analysis) {
    final matched =
        analysis.normalizedExecutables
            .where((e) => blocked.contains(e.toLowerCase()))
            .toSet()
            .toList()
          ..sort();
    if (matched.isEmpty) return allowResult;
    return result(
      onMatch,
      level,
      'Blocked executable(s): ${matched.map((e) => '"$e"').join(', ')}.',
    );
  }
}
