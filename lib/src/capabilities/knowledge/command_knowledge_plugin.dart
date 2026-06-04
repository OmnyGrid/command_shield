import 'command_knowledge.dart';

/// A self-contained unit of command knowledge.
///
/// Each plugin describes one domain (git, the filesystem, package managers, …)
/// by returning a list of [CommandKnowledge] entries. The `CommandKnowledgeBase`
/// composes plugins into a single lookup table, so teaching the base about new
/// tools is a matter of supplying another plugin.
abstract interface class CommandKnowledgePlugin {
  /// A short identifier for the plugin (used in diagnostics and tests).
  String get name;

  /// The command knowledge this plugin contributes.
  List<CommandKnowledge> get entries;
}

/// A [CommandKnowledgePlugin] backed by a fixed list of [entries], so callers
/// can register ad-hoc knowledge without declaring a class.
final class ListKnowledgePlugin implements CommandKnowledgePlugin {
  /// Creates a list-backed plugin.
  const ListKnowledgePlugin(this.name, this.entries);

  @override
  final String name;

  @override
  final List<CommandKnowledge> entries;
}
