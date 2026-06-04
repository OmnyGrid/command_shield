import 'package:meta/meta.dart' show immutable;

import '../../security/security_level.dart';
import '../capability.dart';
import 'command_knowledge.dart';

/// The full result of analysing a single command invocation against the
/// command knowledge base.
///
/// It bundles the detected [capabilities], an aggregated [risk] hint, the
/// matched [knowledge] entry (if the command was recognised) and any
/// explanatory [notes] gathered from the rules that fired.
@immutable
final class CommandKnowledgeResult {
  /// Creates a knowledge result.
  const CommandKnowledgeResult({
    required this.capabilities,
    required this.risk,
    required this.knowledge,
    required this.notes,
  });

  /// A result for a command the base knows nothing about.
  static const CommandKnowledgeResult unknown = CommandKnowledgeResult(
    capabilities: <CommandCapability>{},
    risk: SecurityLevel.safe,
    knowledge: null,
    notes: <String>[],
  );

  /// The capabilities the invocation may exercise.
  final Set<CommandCapability> capabilities;

  /// The aggregated risk hint: the maximum of the matched entry's base risk,
  /// every fired rule's risk, and any wrapped command's risk.
  final SecurityLevel risk;

  /// The matched knowledge entry, or `null` if the command is unknown.
  final CommandKnowledge? knowledge;

  /// Human-readable notes from the rules that matched, in order.
  final List<String> notes;

  /// Whether the command was recognised by the base.
  bool get isKnown => knowledge != null;

  @override
  String toString() =>
      'CommandKnowledgeResult(known: $isKnown, risk: ${risk.name}, '
      'capabilities: $capabilities)';
}
