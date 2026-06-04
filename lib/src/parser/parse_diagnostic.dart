import 'package:meta/meta.dart' show immutable;

/// The severity of a [ParseDiagnostic].
enum DiagnosticSeverity {
  /// Informational; does not indicate a problem.
  info,

  /// A potential problem that did not prevent parsing.
  warning,

  /// A problem that prevented part (or all) of the input from being parsed.
  error,
}

/// A single diagnostic produced while parsing a command line.
///
/// Parsers never throw on malformed input; instead they record diagnostics and
/// return the best-effort AST they could build. This keeps the analysis
/// pipeline crash-free for adversarial input.
@immutable
final class ParseDiagnostic {
  /// Creates a parse diagnostic.
  const ParseDiagnostic({
    required this.severity,
    required this.message,
    this.offset = 0,
  });

  /// Convenience constructor for an [DiagnosticSeverity.info] diagnostic.
  const ParseDiagnostic.info(String message, {int offset = 0})
    : this(severity: DiagnosticSeverity.info, message: message, offset: offset);

  /// Convenience constructor for a [DiagnosticSeverity.warning] diagnostic.
  const ParseDiagnostic.warning(String message, {int offset = 0})
    : this(
        severity: DiagnosticSeverity.warning,
        message: message,
        offset: offset,
      );

  /// Convenience constructor for a [DiagnosticSeverity.error] diagnostic.
  const ParseDiagnostic.error(String message, {int offset = 0})
    : this(
        severity: DiagnosticSeverity.error,
        message: message,
        offset: offset,
      );

  /// How serious the diagnostic is.
  final DiagnosticSeverity severity;

  /// A human-readable explanation of the diagnostic.
  final String message;

  /// The zero-based character offset into the raw input the diagnostic refers
  /// to. Defaults to `0` when no precise location is available.
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is ParseDiagnostic &&
      other.severity == severity &&
      other.message == message &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(severity, message, offset);

  @override
  String toString() => '[${severity.name}] $message (offset: $offset)';
}
