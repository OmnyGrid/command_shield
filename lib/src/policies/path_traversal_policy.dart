import '../analysis/command_analysis.dart';
import '../security/security_level.dart';
import '../validation/command_decision.dart';
import '../validation/command_result.dart';
import 'command_policy.dart';

/// Flags commands that contain path-traversal sequences (`../`, `..\`).
///
/// It relies on the `path-traversal` security findings produced during
/// analysis. By default a traversal yields [CommandDecision.review].
class PathTraversalPolicy extends CommandPolicy {
  /// Creates the policy.
  const PathTraversalPolicy({
    this.onMatch = CommandDecision.review,
    this.includeBareParentReference = false,
  });

  /// The decision returned when traversal is detected.
  final CommandDecision onMatch;

  /// Whether a bare `..` (without a separator) also triggers the policy.
  final bool includeBareParentReference;

  @override
  String get name => 'path-traversal';

  @override
  CommandResult evaluate(CommandAnalysis analysis) {
    final relevant = analysis.findings.where((f) {
      if (f.code != 'path-traversal') return false;
      if (!includeBareParentReference && f.level == SecurityLevel.lowRisk) {
        return false;
      }
      return true;
    }).toList();
    if (relevant.isEmpty) return allowResult;
    return result(
      onMatch,
      relevant.first.level,
      'Path traversal detected: ${relevant.first.message}',
    );
  }
}
