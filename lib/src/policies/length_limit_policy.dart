import '../analysis/command_analysis.dart';
import '../security/security_level.dart';
import '../validation/command_decision.dart';
import '../validation/command_result.dart';
import 'command_policy.dart';

/// Flags commands whose raw length exceeds [maxLength] characters.
///
/// Excessively long command lines are a common sign of obfuscation or
/// injection. Exceeding the limit yields [onExceed] (default
/// [CommandDecision.review]).
class LengthLimitPolicy extends CommandPolicy {
  /// Creates the policy with a maximum raw length of [maxLength] characters.
  const LengthLimitPolicy({
    this.maxLength = 4096,
    this.onExceed = CommandDecision.review,
    this.level = SecurityLevel.mediumRisk,
  }) : assert(maxLength >= 0, 'maxLength must be non-negative');

  /// The maximum permitted length of the raw command, in characters.
  final int maxLength;

  /// The decision returned when the limit is exceeded.
  final CommandDecision onExceed;

  /// The severity attached to the finding.
  final SecurityLevel level;

  @override
  String get name => 'length-limit';

  @override
  CommandResult evaluate(CommandAnalysis analysis) {
    final length = analysis.raw.length;
    if (length <= maxLength) return allowResult;
    return result(
      onExceed,
      level,
      'Command length ($length) exceeds the limit of $maxLength characters.',
    );
  }
}
