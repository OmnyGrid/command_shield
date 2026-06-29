import '../../capability.dart';
import '../command_knowledge.dart';

/// Builds a list of simple [CommandKnowledge] entries that share the same
/// [category], [platforms] and [capabilities] — one entry per name in [names].
///
/// Used by plugins for the many commands whose capabilities do not depend on
/// their arguments (e.g. every read-only inspection tool).
List<CommandKnowledge> simpleEntries(
  Iterable<String> names,
  KnowledgeCategory category,
  Set<CommandCapability> capabilities, {
  Set<CommandPlatform> platforms = const {CommandPlatform.cross},
  Set<String> informationalTokens = const <String>{},
}) => [
  for (final n in names)
    CommandKnowledge(
      executable: n,
      category: category,
      platforms: platforms,
      baseCapabilities: capabilities,
      informationalTokens: informationalTokens,
    ),
];
