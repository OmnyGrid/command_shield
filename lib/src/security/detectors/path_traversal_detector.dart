import '../security_detector.dart';
import '../security_finding.dart';
import '../security_level.dart';

/// Detects path-traversal sequences (`../`, `..\`) in command arguments.
///
/// Traversal can escape an intended working directory, so it is reported at
/// [SecurityLevel.mediumRisk]. A bare `..` with no separator is reported at
/// [SecurityLevel.lowRisk] to limit false positives (e.g. git ranges).
final class PathTraversalDetector extends SecurityDetector {
  /// Creates the detector.
  const PathTraversalDetector();

  @override
  String get code => 'path-traversal';

  static final RegExp _traversal = RegExp(r'\.\.[\\/]');

  @override
  List<SecurityFinding> detect(SecurityContext context) {
    final findings = <SecurityFinding>[];
    var reportedTraversal = false;
    var reportedBare = false;

    for (final inv in context.invocations) {
      for (final arg in inv.arguments) {
        if (_traversal.hasMatch(arg)) {
          if (!reportedTraversal) {
            reportedTraversal = true;
            findings.add(
              SecurityFinding(
                level: SecurityLevel.mediumRisk,
                message:
                    'Path traversal sequence ("../" or "..\\") in '
                    'argument "$arg".',
                code: code,
              ),
            );
          }
        } else if (!reportedBare && (arg == '..' || arg.endsWith('/..'))) {
          reportedBare = true;
          findings.add(
            SecurityFinding(
              level: SecurityLevel.lowRisk,
              message: 'Parent-directory reference ("..") in argument "$arg".',
              code: code,
            ),
          );
        }
      }
    }
    return findings;
  }
}
