import '../analysis/command_analysis.dart';
import '../security/security_level.dart';
import '../validation/command_decision.dart';
import '../validation/command_result.dart';
import 'command_policy.dart';

/// Rejects commands whose arguments match a forbidden regular expression.
///
/// By default every argument of every invocation is tested; set
/// [matchWholeCommand] to test the raw command string instead.
class ArgumentPatternPolicy extends CommandPolicy {
  /// Creates the policy.
  const ArgumentPatternPolicy({
    required this.pattern,
    this.description,
    this.onMatch = CommandDecision.deny,
    this.level = SecurityLevel.highRisk,
    this.matchWholeCommand = false,
  });

  /// The pattern that, when matched, triggers [onMatch].
  final RegExp pattern;

  /// An optional human-readable description of what the pattern guards against.
  final String? description;

  /// The decision returned on a match.
  final CommandDecision onMatch;

  /// The severity attached to the finding.
  final SecurityLevel level;

  /// When `true`, [pattern] is matched against the raw command string;
  /// otherwise it is matched against individual arguments.
  final bool matchWholeCommand;

  @override
  String get name => 'argument-pattern';

  @override
  CommandResult evaluate(CommandAnalysis analysis) {
    if (matchWholeCommand) {
      if (!pattern.hasMatch(analysis.raw)) return allowResult;
      return _deny(analysis.raw);
    }
    for (final inv in analysis.invocations) {
      for (final arg in inv.arguments) {
        if (pattern.hasMatch(arg)) return _deny(arg);
      }
    }
    return allowResult;
  }

  CommandResult _deny(String matched) => result(
    onMatch,
    level,
    '${description ?? 'Argument matches forbidden pattern'} '
    '(/${pattern.pattern}/) in "$matched".',
  );
}
