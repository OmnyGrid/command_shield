import '../analysis/command_analysis.dart';
import '../security/security_finding.dart';
import '../security/security_level.dart';
import '../validation/command_decision.dart';
import '../validation/command_result.dart';

/// A composable validation rule that turns a [CommandAnalysis] into a
/// [CommandResult].
///
/// Policies are pure and deterministic. Combine several with a [PolicySet];
/// the combined verdict is always the most restrictive individual verdict.
abstract class CommandPolicy {
  /// Const base constructor for subclasses.
  const CommandPolicy();

  /// A short, stable identifier for the policy (used in findings/tests).
  String get name;

  /// Evaluates [analysis] and returns a result.
  CommandResult evaluate(CommandAnalysis analysis);

  /// Helper to build a result carrying a single finding.
  CommandResult result(
    CommandDecision decision,
    SecurityLevel level,
    String message,
  ) => CommandResult(
    decision: decision,
    securityLevel: level,
    findings: <SecurityFinding>[
      SecurityFinding(level: level, message: message, code: name),
    ],
  );

  /// Helper to build an allow result with no findings.
  CommandResult get allowResult => const CommandResult.allow();
}

/// A composite policy that evaluates several [policies] and merges their
/// results into a single, most-restrictive [CommandResult].
class PolicySet extends CommandPolicy {
  /// Creates a policy set from [policies].
  const PolicySet(this.policies, {this.name = 'policy-set'});

  /// The member policies, evaluated in order.
  final List<CommandPolicy> policies;

  @override
  final String name;

  /// Returns a new set with [policy] appended.
  PolicySet add(CommandPolicy policy) =>
      PolicySet(<CommandPolicy>[...policies, policy], name: name);

  @override
  CommandResult evaluate(CommandAnalysis analysis) {
    var result = CommandResult(
      decision: CommandDecision.allow,
      securityLevel: analysis.securityLevel,
      findings: const <SecurityFinding>[],
    );
    for (final policy in policies) {
      result = result.merge(policy.evaluate(analysis));
    }
    return result;
  }
}
