import '../analysis/command_analysis.dart';
import '../security/security_level.dart';
import '../validation/command_decision.dart';
import '../validation/command_result.dart';
import 'command_policy.dart';

/// Flags inline shell execution (`bash -c`, `sh -c`, `cmd /c`,
/// `powershell -Command`, `-EncodedCommand`).
///
/// It relies on the `shell-execution` security findings. Because inline shell
/// execution can run arbitrary code, the default decision is
/// [CommandDecision.deny].
class ShellExecutionPolicy extends CommandPolicy {
  /// Creates the policy.
  const ShellExecutionPolicy({this.onMatch = CommandDecision.deny});

  /// The decision returned when inline shell execution is detected.
  final CommandDecision onMatch;

  @override
  String get name => 'shell-execution';

  @override
  CommandResult evaluate(CommandAnalysis analysis) {
    final relevant = analysis.findings
        .where((f) => f.code == 'shell-execution')
        .toList();
    if (relevant.isEmpty) return allowResult;
    final level = relevant.fold<SecurityLevel>(
      SecurityLevel.safe,
      (acc, f) => acc.max(f.level),
    );
    return result(onMatch, level, relevant.first.message);
  }
}
