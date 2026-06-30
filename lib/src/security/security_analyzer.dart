import 'package:meta/meta.dart' show immutable;

import 'detectors/benign_redirection_detector.dart';
import 'detectors/command_substitution_detector.dart';
import 'detectors/dangerous_operator_detector.dart';
import 'detectors/destructive_command_detector.dart';
import 'detectors/env_expansion_detector.dart';
import 'detectors/path_traversal_detector.dart';
import 'detectors/privilege_escalation_detector.dart';
import 'detectors/remote_exec_detector.dart';
import 'detectors/shell_execution_detector.dart';
import 'security_detector.dart';
import 'security_finding.dart';
import 'security_level.dart';

/// The result of running every [SecurityDetector] over a command.
@immutable
final class SecurityReport {
  /// Creates a security report.
  const SecurityReport({required this.level, required this.findings});

  /// The overall severity: the maximum [SecurityLevel] across [findings], or
  /// [SecurityLevel.safe] when there are none.
  final SecurityLevel level;

  /// All findings, sorted by descending severity then by detector code for
  /// deterministic output.
  final List<SecurityFinding> findings;
}

/// Runs the full suite of security detectors and aggregates their findings.
///
/// The detector list is extensible: pass custom [detectors] (or extend the
/// [defaultDetectors]).
final class SecurityAnalyzer {
  /// Creates an analyzer.
  ///
  /// When [detectors] is omitted the [defaultDetectors] are used.
  SecurityAnalyzer({List<SecurityDetector>? detectors})
    : detectors = detectors ?? defaultDetectors;

  /// The detectors run by [analyze].
  final List<SecurityDetector> detectors;

  /// The built-in detector suite, in a stable order.
  static const List<SecurityDetector> defaultDetectors = <SecurityDetector>[
    DangerousOperatorDetector(),
    CommandSubstitutionDetector(),
    ShellExecutionDetector(),
    PrivilegeEscalationDetector(),
    DestructiveCommandDetector(),
    RemoteExecDetector(),
    PathTraversalDetector(),
    EnvExpansionDetector(),
    BenignRedirectionDetector(),
  ];

  /// Runs all [detectors] over [context] and aggregates the result.
  SecurityReport analyze(SecurityContext context) {
    final findings = <SecurityFinding>[];
    for (final detector in detectors) {
      findings.addAll(detector.detect(context));
    }
    findings.sort((a, b) {
      final byLevel = b.level.index.compareTo(a.level.index);
      if (byLevel != 0) return byLevel;
      final byCode = a.code.compareTo(b.code);
      if (byCode != 0) return byCode;
      return (a.offset ?? -1).compareTo(b.offset ?? -1);
    });

    var level = SecurityLevel.safe;
    for (final f in findings) {
      level = level.max(f.level);
    }
    return SecurityReport(
      level: level,
      findings: List<SecurityFinding>.unmodifiable(findings),
    );
  }
}
