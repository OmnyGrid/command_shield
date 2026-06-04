import '../../capabilities/command_knowledge_base.dart';
import '../security_detector.dart';
import '../security_finding.dart';
import '../security_level.dart';

/// Surfaces the risk hints carried by the [CommandKnowledgeBase] as security
/// findings.
///
/// Each invocation is looked up in the knowledge base; when its aggregated risk
/// exceeds [SecurityLevel.safe], a finding is emitted with the matched rule's
/// explanation (for example, a `git push --force`).
///
/// This detector is **opt-in**: it is *not* part of
/// `SecurityAnalyzer.defaultDetectors`, because the built-in destructive,
/// privilege-escalation and remote-exec detectors already cover the genuinely
/// dangerous cases and most knowledge entries carry no elevated risk. Add it
/// explicitly to enable knowledge-driven findings:
///
/// ```dart
/// final analyzer = SecurityAnalyzer(detectors: [
///   ...SecurityAnalyzer.defaultDetectors,
///   const KnowledgeRiskDetector(),
/// ]);
/// ```
final class KnowledgeRiskDetector extends SecurityDetector {
  /// Creates the detector, optionally with a custom [knowledgeBase].
  KnowledgeRiskDetector({CommandKnowledgeBase? knowledgeBase})
    : _knowledgeBase = knowledgeBase ?? CommandKnowledgeBase.standard();

  final CommandKnowledgeBase _knowledgeBase;

  @override
  String get code => 'knowledge-risk';

  @override
  List<SecurityFinding> detect(SecurityContext context) {
    final findings = <SecurityFinding>[];
    for (final inv in context.invocations) {
      if (inv.executable.isEmpty) continue;
      final exe = context.normalizedExecutable(inv);
      final result = _knowledgeBase.analyze(exe, inv.arguments);
      if (result.risk.isAtLeast(SecurityLevel.lowRisk)) {
        final detail = result.notes.isNotEmpty
            ? ' (${result.notes.join('; ')})'
            : '';
        findings.add(
          SecurityFinding(
            level: result.risk,
            message: 'Elevated-risk command "$exe"$detail.',
            code: code,
          ),
        );
      }
    }
    return findings;
  }
}
