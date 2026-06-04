import '../ast/command_node.dart';
import '../normalization/normalizer.dart';
import 'capability.dart';
import 'command_knowledge_base.dart';

/// Detects the [CommandCapability]s exercised by a parsed command tree.
///
/// Executables are normalized before being looked up in the
/// [CommandKnowledgeBase], and structural features of the AST (redirections,
/// command substitutions, environment references) contribute capabilities of
/// their own.
final class CapabilityDetector {
  /// Creates a capability detector.
  ///
  /// Supply a custom [normalizer] or [knowledgeBase] to extend behaviour.
  CapabilityDetector({
    Normalizer? normalizer,
    CommandKnowledgeBase? knowledgeBase,
  }) : _normalizer = normalizer ?? Normalizer.standard(),
       _knowledgeBase = knowledgeBase ?? CommandKnowledgeBase();

  final Normalizer _normalizer;
  final CommandKnowledgeBase _knowledgeBase;

  /// Returns the union of all capabilities found anywhere in [node].
  Set<CommandCapability> detect(CommandNode node) {
    final result = <CommandCapability>{};
    for (final n in node.walk()) {
      switch (n) {
        case CommandInvocation():
          _detectInvocation(n, result);
        case EnvironmentVariableReference():
          result.add(CommandCapability.environmentAccess);
        case CommandSubstitution():
          // A substitution runs a command to produce text.
          result.add(CommandCapability.executePrograms);
        case RedirectionNode():
          _detectRedirection(n, result);
        case Pipeline():
        case CommandChain():
        case CommandScript():
          break;
      }
    }
    return result;
  }

  void _detectInvocation(CommandInvocation inv, Set<CommandCapability> out) {
    if (inv.executable.isEmpty) return;
    final normalized = _normalizer.normalize(inv.executable);
    out.addAll(_knowledgeBase.capabilitiesFor(normalized, inv.arguments));
  }

  void _detectRedirection(RedirectionNode redir, Set<CommandCapability> out) {
    switch (redir.type) {
      case RedirectionType.output:
      case RedirectionType.appendOutput:
      case RedirectionType.errorOutput:
      case RedirectionType.appendErrorOutput:
        out.add(CommandCapability.writeFilesystem);
      case RedirectionType.input:
      case RedirectionType.hereDocument:
        out.add(CommandCapability.readFilesystem);
    }
  }
}
