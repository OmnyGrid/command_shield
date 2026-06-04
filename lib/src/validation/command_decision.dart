/// The final verdict produced by the policy engine for a command.
///
/// The values are ordered from least to most restrictive so they can be
/// combined by taking the maximum.
enum CommandDecision {
  /// The command is permitted to run.
  allow,

  /// The command should be held for human review before running.
  review,

  /// The command must not run.
  deny,
}

/// Ordering helpers for [CommandDecision].
extension CommandDecisionCombine on CommandDecision {
  /// Returns the more restrictive of `this` and [other]
  /// (`deny` > `review` > `allow`).
  CommandDecision mostRestrictive(CommandDecision other) =>
      index >= other.index ? this : other;
}
