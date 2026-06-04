import '../../ast/command_node.dart';
import '../security_detector.dart';
import '../security_finding.dart';
import '../security_level.dart';

/// Detects environment-variable expansion: `$HOME`, `${HOME}`, `%USERPROFILE%`
/// and `$env:USERPROFILE`.
///
/// Expansion can change a command's meaning depending on the environment, so it
/// is reported at [SecurityLevel.lowRisk]. Detection uses the parsed
/// [EnvironmentVariableReference] nodes and a raw-text fallback for syntaxes
/// where references are not parsed structurally.
final class EnvExpansionDetector extends SecurityDetector {
  /// Creates the detector.
  const EnvExpansionDetector();

  @override
  String get code => 'env-expansion';

  static final RegExp _rawPattern = RegExp(
    r'(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?)'
    r'|(\$env:[A-Za-z_][A-Za-z0-9_]*)'
    r'|(%[A-Za-z_][A-Za-z0-9_]*%)',
  );

  @override
  List<SecurityFinding> detect(SecurityContext context) {
    final names = <String>{};
    final ast = context.ast;
    if (ast != null) {
      for (final node in ast.walk()) {
        if (node is EnvironmentVariableReference) {
          names.add(node.variable);
        }
      }
    }
    if (names.isEmpty) {
      for (final match in _rawPattern.allMatches(context.singleUnquotedRaw)) {
        names.add(match.group(0)!);
      }
    }
    if (names.isEmpty) return const <SecurityFinding>[];

    final sorted = names.toList()..sort();
    return <SecurityFinding>[
      SecurityFinding(
        level: SecurityLevel.lowRisk,
        message: 'Environment-variable expansion (${sorted.join(', ')}).',
        code: code,
      ),
    ];
  }
}
