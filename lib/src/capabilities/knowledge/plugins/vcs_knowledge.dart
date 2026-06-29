import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about version-control tools other than `git` (which has its own
/// deeply-refined plugin).
///
/// The DVCS tools (`hg`, `svn`, `bzr`, `fossil`, `cvs`, `jj`) share git's
/// read/write/network split, so they reuse a common set of sub-command rules
/// with a read-only floor. The TUIs/helpers (`tig`, `lazygit`) just browse and
/// edit a local repository.
final class VcsKnowledge implements CommandKnowledgePlugin {
  /// Creates the version-control knowledge plugin.
  const VcsKnowledge();

  @override
  String get name => 'vcs';

  static const _vc = KnowledgeCategory.versionControl;

  static const _push = SubcommandRule(
    {'push', 'dpush'},
    {CommandCapability.networkWrite},
    description: 'Uploads commits/changes to a remote.',
  );

  static const _pullish = SubcommandRule(
    {'pull', 'clone', 'fetch', 'incoming', 'outgoing', 'co', 'checkout'},
    {CommandCapability.networkRead},
    description: 'Downloads changes from a remote.',
  );

  static const _writeRepo = SubcommandRule(
    {
      'commit',
      'ci',
      'add',
      'update',
      'up',
      'merge',
      'rebase',
      'revert',
      'backout',
      'rm',
      'remove',
      'mv',
      'rename',
      'import',
      'init',
      'tag',
      'branch',
      'strip',
      'rollback',
      'amend',
      'new',
      'squash',
      'split',
    },
    {CommandCapability.writeFilesystem},
    description: 'Modifies the working tree or repository.',
  );

  @override
  List<CommandKnowledge> get entries => [
    for (final c in const ['hg', 'svn', 'bzr', 'fossil', 'cvs', 'jj'])
      CommandKnowledge(
        executable: c,
        category: _vc,
        description: 'Version-control system.',
        baseCapabilities: const {CommandCapability.readFilesystem},
        subcommands: const [_push, _pullish, _writeRepo],
      ),

    // git-lfs always talks to a remote object store.
    const CommandKnowledge(
      executable: 'git-lfs',
      category: _vc,
      description: 'Git Large File Storage client.',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.networkRead,
        CommandCapability.networkWrite,
      },
    ),

    // glab is the GitLab CLI — a network client like `gh`.
    const CommandKnowledge(
      executable: 'glab',
      category: _vc,
      description: 'GitLab CLI (network access; may run actions).',
      baseCapabilities: {
        CommandCapability.networkRead,
        CommandCapability.networkWrite,
      },
    ),

    // Local repository browsers/editors.
    ...simpleEntries(
      const ['tig', 'lazygit', 'gitk', 'gitui'],
      _vc,
      const {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
      },
    ),
  ];
}
