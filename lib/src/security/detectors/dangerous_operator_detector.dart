import '../security_detector.dart';
import '../security_finding.dart';
import '../security_level.dart';

/// Detects shell control operators in the raw command: `;`, `&&`, `||`, `|`,
/// `>`, `>>`, `<`, `<<`.
///
/// Operators inside quotes are ignored. Command chaining (`;`, `&&`, `||`) is
/// reported at [SecurityLevel.mediumRisk] because it can hide a second payload;
/// pipelines and redirections are [SecurityLevel.lowRisk].
final class DangerousOperatorDetector extends SecurityDetector {
  /// Creates the detector.
  const DangerousOperatorDetector();

  @override
  String get code => 'dangerous-operator';

  @override
  List<SecurityFinding> detect(SecurityContext context) {
    final s = context.unquotedRaw;
    final findings = <SecurityFinding>[];
    final seen = <String>{};

    void add(String op, SecurityLevel level, String description, int offset) {
      if (seen.add(op)) {
        findings.add(
          SecurityFinding(
            level: level,
            message: '$description operator "$op" present.',
            code: code,
            offset: offset,
          ),
        );
      }
    }

    var i = 0;
    final n = s.length;
    while (i < n) {
      final ch = s[i];
      final next = i + 1 < n ? s[i + 1] : '';
      switch (ch) {
        case '&':
          if (next == '&') {
            add('&&', SecurityLevel.mediumRisk, 'Conditional-AND chaining', i);
            i += 2;
            continue;
          }
        case '|':
          if (next == '|') {
            add('||', SecurityLevel.mediumRisk, 'Conditional-OR chaining', i);
            i += 2;
            continue;
          }
          add('|', SecurityLevel.lowRisk, 'Pipeline', i);
        case ';':
          add(';', SecurityLevel.mediumRisk, 'Sequential chaining', i);
        case '>':
          if (next == '>') {
            add('>>', SecurityLevel.lowRisk, 'Append redirection', i);
            i += 2;
            continue;
          }
          add('>', SecurityLevel.lowRisk, 'Output redirection', i);
        case '<':
          if (next == '<') {
            add('<<', SecurityLevel.lowRisk, 'Here-document redirection', i);
            i += 2;
            continue;
          }
          add('<', SecurityLevel.lowRisk, 'Input redirection', i);
      }
      i++;
    }
    return findings;
  }
}
