import '../security_detector.dart';
import '../security_finding.dart';
import '../security_level.dart';

/// Detects invocations that execute an arbitrary command string supplied as an
/// argument: `bash -c`, `sh -c`, `cmd /c`, `powershell -Command`, etc.
///
/// These are reported at [SecurityLevel.highRisk]; PowerShell's
/// `-EncodedCommand` is [SecurityLevel.critical] because it conceals intent.
final class ShellExecutionDetector extends SecurityDetector {
  /// Creates the detector.
  const ShellExecutionDetector();

  @override
  String get code => 'shell-execution';

  static const Set<String> _cFlagShells = <String>{
    'bash',
    'sh',
    'zsh',
    'dash',
    'ksh',
    'fish',
  };

  @override
  List<SecurityFinding> detect(SecurityContext context) {
    final findings = <SecurityFinding>[];
    for (final inv in context.invocations) {
      final exe = context.normalizedExecutable(inv).toLowerCase();
      final args = inv.arguments;

      if (_cFlagShells.contains(exe) &&
          args.any((a) => a == '-c' || a == '--command')) {
        findings.add(
          SecurityFinding(
            level: SecurityLevel.highRisk,
            message:
                'Inline shell execution via "$exe -c" runs an arbitrary '
                'command string.',
            code: code,
          ),
        );
      } else if (exe == 'cmd' &&
          args.any((a) {
            final l = a.toLowerCase();
            return l == '/c' || l == '/k';
          })) {
        findings.add(
          SecurityFinding(
            level: SecurityLevel.highRisk,
            message:
                'Inline shell execution via "cmd /c" runs an arbitrary '
                'command string.',
            code: code,
          ),
        );
      } else if (exe == 'powershell' || exe == 'pwsh') {
        final lower = args.map((a) => a.toLowerCase()).toList();
        const encodedForms = <String>{'-e', '-ec', '-enc', '-encodedcommand'};
        if (lower.any(
          (a) => encodedForms.contains(a) || a.startsWith('-encoded'),
        )) {
          findings.add(
            SecurityFinding(
              level: SecurityLevel.critical,
              message:
                  'Obfuscated PowerShell via "-EncodedCommand" conceals '
                  'the executed code.',
              code: code,
            ),
          );
        } else if (lower.any((a) => a.startsWith('-c') || a == '-command')) {
          findings.add(
            SecurityFinding(
              level: SecurityLevel.highRisk,
              message:
                  'Inline shell execution via "powershell -Command" runs '
                  'an arbitrary command string.',
              code: code,
            ),
          );
        }
      }
    }
    return findings;
  }
}
