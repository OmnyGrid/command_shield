import '../security_detector.dart';
import '../security_finding.dart';
import '../security_level.dart';

/// Detects command substitution: `$(...)` and back-tick `` `...` ``.
///
/// Command substitution executes a nested command and inlines its output, so
/// it is reported at [SecurityLevel.mediumRisk]. Substitutions inside single
/// quotes are ignored.
final class CommandSubstitutionDetector extends SecurityDetector {
  /// Creates the detector.
  const CommandSubstitutionDetector();

  @override
  String get code => 'command-substitution';

  @override
  List<SecurityFinding> detect(SecurityContext context) {
    final s = context.singleUnquotedRaw;
    final findings = <SecurityFinding>[];

    final dollar = s.indexOf(r'$(');
    if (dollar >= 0) {
      findings.add(
        SecurityFinding(
          level: SecurityLevel.mediumRisk,
          message: r'Command substitution "$(...)" executes a nested command.',
          code: code,
          offset: dollar,
        ),
      );
    }
    final backtick = s.indexOf('`');
    if (backtick >= 0) {
      findings.add(
        SecurityFinding(
          level: SecurityLevel.mediumRisk,
          message: 'Back-tick command substitution executes a nested command.',
          code: code,
          offset: backtick,
        ),
      );
    }
    return findings;
  }
}
