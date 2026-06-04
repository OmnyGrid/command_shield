import '../security_detector.dart';
import '../security_finding.dart';
import '../security_level.dart';

/// Detects privilege-escalation commands: `sudo`, `su`, `runas`, `doas`,
/// `pkexec`.
///
/// Reported at [SecurityLevel.highRisk].
final class PrivilegeEscalationDetector extends SecurityDetector {
  /// Creates the detector.
  const PrivilegeEscalationDetector();

  @override
  String get code => 'privilege-escalation';

  @override
  List<SecurityFinding> detect(SecurityContext context) {
    final findings = <SecurityFinding>[];
    for (final inv in context.invocations) {
      final exe = context.normalizedExecutable(inv).toLowerCase();
      if (CommandFamilies.privilege.contains(exe)) {
        findings.add(
          SecurityFinding(
            level: SecurityLevel.highRisk,
            message: 'Privilege escalation via "$exe".',
            code: code,
          ),
        );
      }
    }
    return findings;
  }
}
