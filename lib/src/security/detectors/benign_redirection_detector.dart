import '../../ast/command_node.dart';
import '../security_detector.dart';
import '../security_finding.dart';
import '../security_level.dart';

/// Records innocuous I/O redirections as explicit, [SecurityLevel.safe]
/// findings so they are visible for auditing without affecting the decision.
///
/// Two redirection shapes are benign no-ops for the filesystem:
///
/// * **Stream merges** — file-descriptor duplication such as `2>&1`, `1>&2` or
///   `>&2`, which wire one stream into another and write no file.
/// * **Null-sink discards** — redirecting to `/dev/null`, `NUL` or `$null`,
///   which throws the stream away.
///
/// These commonly trail otherwise-ordinary commands (`cmd 2>&1`,
/// `cmd >/dev/null 2>&1`); surfacing them as `safe` keeps the audit trail
/// honest while guaranteeing they never push a command toward REVIEW/DENY
/// (`safe` is below every actionable level).
final class BenignRedirectionDetector extends SecurityDetector {
  /// Creates the detector.
  const BenignRedirectionDetector();

  @override
  String get code => 'benign-redirection';

  @override
  List<SecurityFinding> detect(SecurityContext context) {
    final findings = <SecurityFinding>[];
    for (final inv in context.invocations) {
      for (final redir in inv.redirections) {
        final description = _benignDescription(redir);
        if (description == null) continue;
        findings.add(
          SecurityFinding(
            level: SecurityLevel.safe,
            message: description,
            code: code,
          ),
        );
      }
    }
    return findings;
  }

  /// A human-readable note when [redir] is a benign no-op, otherwise `null`.
  static String? _benignDescription(RedirectionNode redir) {
    switch (redir.type) {
      case RedirectionType.mergeStreams:
        return 'Benign redirection "${redir.target}" '
            '(stream merge); writes no file.';
      case RedirectionType.output:
      case RedirectionType.appendOutput:
      case RedirectionType.errorOutput:
      case RedirectionType.appendErrorOutput:
      case RedirectionType.combinedOutput:
      case RedirectionType.combinedAppendOutput:
      case RedirectionType.input:
      case RedirectionType.hereDocument:
        if (_isNullSink(redir.target)) {
          return 'Benign redirection to null sink "${redir.target}"; '
              'discards the stream.';
        }
        return null;
    }
  }

  /// Whether [target] is a discard sink that reads/writes no real file:
  /// `/dev/null` (POSIX), `NUL`/`NUL:` (Windows), or `$null` (PowerShell).
  static bool _isNullSink(String target) {
    final t = target.toLowerCase();
    return t == '/dev/null' || t == 'nul' || t == 'nul:' || t == r'$null';
  }
}
