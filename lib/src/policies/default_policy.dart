import '../validation/command_decision.dart';
import 'command_policy.dart';
import 'length_limit_policy.dart';
import 'risk_threshold_policy.dart';
import 'shell_execution_policy.dart';

/// Builds the default [PolicySet] used by `CommandShield` when no custom policy
/// is supplied.
///
/// The default is intentionally conservative but not paranoid:
///
/// * [RiskThresholdPolicy] — review at medium risk, deny at critical.
/// * [ShellExecutionPolicy] — inline shell execution (`bash -c`, ...) is held
///   for review.
/// * [LengthLimitPolicy] — extremely long commands (obfuscation) are reviewed.
///
/// This reproduces the documented example outcomes: `git status` ⇒ allow,
/// `rm -rf build` ⇒ review, `rm -rf /` and `curl ... | bash` ⇒ deny.
PolicySet buildDefaultPolicy() => const PolicySet(<CommandPolicy>[
  RiskThresholdPolicy(),
  ShellExecutionPolicy(onMatch: CommandDecision.review),
  LengthLimitPolicy(maxLength: 8192),
], name: 'default');
