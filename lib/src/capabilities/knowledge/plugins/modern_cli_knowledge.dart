import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about modern command-line tools commonly used by developers and
/// AI agents (structured-data processors, file finders, better `cat`/`ls`/grep
/// replacements).
///
/// These are overwhelmingly read-only inspectors; the few that can edit files
/// in place (`sd`, `jq`/`yq` with `-i`) gain `writeFilesystem` via an argument
/// rule.
final class ModernCliKnowledge implements CommandKnowledgePlugin {
  /// Creates the modern-CLI knowledge plugin.
  const ModernCliKnowledge();

  @override
  String get name => 'modernCli';

  static const _fs = KnowledgeCategory.filesystem;

  static const _inPlace = ArgumentRule(
    PrefixFlag({'-i', '--in-place'}),
    {CommandCapability.writeFilesystem},
    description: 'In-place edit writes to the input file.',
  );

  @override
  List<CommandKnowledge> get entries => [
    // --- read-only inspectors / search / pretty-printers ---
    ...simpleEntries(
      const [
        'fd',
        'rg',
        'ag',
        'ack',
        'bat',
        'eza',
        'exa',
        'lsd',
        'delta',
        'fzf',
        'gron',
        'htmlq',
        'hexyl',
        'tokei',
        'scc',
        'glow',
        'mdcat',
        'zoxide',
        'dust',
        'duf',
        'tldr',
      ],
      _fs,
      const {CommandCapability.readFilesystem},
    ),

    // --- structured-data processors: read, write in place with -i ---
    for (final c in const ['jq', 'yq', 'dasel'])
      CommandKnowledge(
        executable: c,
        category: _fs,
        description: 'Structured-data (JSON/YAML/…) processor.',
        baseCapabilities: const {CommandCapability.readFilesystem},
        argumentRules: const [_inPlace],
      ),

    // sd is a find-and-replace tool; without a file argument it filters stdin,
    // with one it rewrites the file.
    const CommandKnowledge(
      executable: 'sd',
      category: _fs,
      description: 'Intuitive find-and-replace (sed alternative).',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
      },
    ),
  ];
}
