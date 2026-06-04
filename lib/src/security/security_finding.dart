import 'package:meta/meta.dart' show immutable;

import 'security_level.dart';

/// A single, explainable security observation about a command.
///
/// Every finding carries a [level], a human-readable [message] and a stable
/// [code] identifying the detector or rule that produced it (useful for
/// allow-listing, testing and telemetry).
@immutable
final class SecurityFinding {
  /// Creates a security finding.
  const SecurityFinding({
    required this.level,
    required this.message,
    required this.code,
    this.offset,
  });

  /// The severity of this finding.
  final SecurityLevel level;

  /// A human-readable explanation suitable for surfacing to users/agents.
  final String message;

  /// A stable machine identifier for the rule, e.g. `dangerous-operator` or
  /// `remote-exec`.
  final String code;

  /// The character offset into the raw input this finding refers to, if known.
  final int? offset;

  @override
  bool operator ==(Object other) =>
      other is SecurityFinding &&
      other.level == level &&
      other.message == message &&
      other.code == code &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(level, message, code, offset);

  @override
  String toString() => '[${level.name}] $code: $message';
}
