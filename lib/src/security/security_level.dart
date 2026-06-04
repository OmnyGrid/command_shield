/// The severity of a security concern, from least to most dangerous.
///
/// The values are ordered, so they can be compared by [index] or with the
/// [SecurityLevelComparison.isAtLeast] helper.
enum SecurityLevel {
  /// No security concern detected.
  safe,

  /// A minor concern; likely fine but worth noting.
  lowRisk,

  /// A concern that warrants human review.
  mediumRisk,

  /// A serious concern that is likely dangerous.
  highRisk,

  /// A critical concern that is almost certainly destructive or malicious.
  critical,
}

/// Ordering helpers for [SecurityLevel].
extension SecurityLevelComparison on SecurityLevel {
  /// Whether this level is at least as severe as [other].
  bool isAtLeast(SecurityLevel other) => index >= other.index;

  /// Returns the more severe of `this` and [other].
  SecurityLevel max(SecurityLevel other) => index >= other.index ? this : other;
}
