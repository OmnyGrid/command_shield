import '../analysis/command_analysis.dart';
import '../security/security_level.dart';
import '../validation/command_decision.dart';
import '../validation/command_result.dart';
import 'command_policy.dart';

/// Maps the analysis's overall [SecurityLevel] to a [CommandDecision] using two
/// thresholds.
///
/// A command at or above [denyAt] is denied; at or above [reviewAt] (but below
/// [denyAt]) it is held for review; otherwise it is allowed.
///
/// The defaults — review at [SecurityLevel.mediumRisk], deny at
/// [SecurityLevel.critical] — match the documented example outcomes (e.g.
/// `rm -rf build` ⇒ review, `rm -rf /` ⇒ deny).
class RiskThresholdPolicy extends CommandPolicy {
  /// Creates the policy.
  const RiskThresholdPolicy({
    this.reviewAt = SecurityLevel.mediumRisk,
    this.denyAt = SecurityLevel.critical,
  });

  /// The minimum level that triggers [CommandDecision.review].
  final SecurityLevel reviewAt;

  /// The minimum level that triggers [CommandDecision.deny].
  final SecurityLevel denyAt;

  @override
  String get name => 'risk-threshold';

  @override
  CommandResult evaluate(CommandAnalysis analysis) {
    final level = analysis.securityLevel;
    final CommandDecision decision;
    if (level.isAtLeast(denyAt)) {
      decision = CommandDecision.deny;
    } else if (level.isAtLeast(reviewAt)) {
      decision = CommandDecision.review;
    } else {
      decision = CommandDecision.allow;
    }
    if (decision == CommandDecision.allow) {
      return CommandResult(
        decision: CommandDecision.allow,
        securityLevel: level,
        findings: const [],
      );
    }
    return result(
      decision,
      level,
      'Overall risk level "${level.name}" '
      '${decision == CommandDecision.deny ? 'meets the deny' : 'meets the review'}'
      ' threshold.',
    );
  }
}
