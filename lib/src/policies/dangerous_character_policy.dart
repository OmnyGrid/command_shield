import '../analysis/command_analysis.dart';
import '../security/security_level.dart';
import '../validation/command_decision.dart';
import '../validation/command_result.dart';
import 'command_policy.dart';

/// Rejects commands whose raw text contains shell control characters/sequences.
///
/// This is a deliberately strict, defence-in-depth policy: it inspects the raw
/// command directly (including inside quotes) so that no metacharacter slips
/// through. Configure the [forbidden] set and the [onMatch] decision.
class DangerousCharacterPolicy extends CommandPolicy {
  /// Creates the policy.
  const DangerousCharacterPolicy({
    this.forbidden = defaultForbidden,
    this.onMatch = CommandDecision.deny,
    this.level = SecurityLevel.highRisk,
  });

  /// The default forbidden character sequences: chaining, piping, redirection,
  /// command substitution and newlines.
  static const Set<String> defaultForbidden = <String>{
    ';',
    '|',
    '&',
    '`',
    '<',
    '>',
    r'$(',
    '\n',
  };

  /// The forbidden character sequences.
  final Set<String> forbidden;

  /// The decision returned when a forbidden sequence is found.
  final CommandDecision onMatch;

  /// The severity attached to the finding when a sequence is found.
  final SecurityLevel level;

  @override
  String get name => 'dangerous-character';

  @override
  CommandResult evaluate(CommandAnalysis analysis) {
    final hits = forbidden.where(analysis.raw.contains).toList()..sort();
    if (hits.isEmpty) return allowResult;
    return result(
      onMatch,
      level,
      'Command contains forbidden character sequence(s): '
      '${hits.map((h) => '"$h"').join(', ')}.',
    );
  }
}
