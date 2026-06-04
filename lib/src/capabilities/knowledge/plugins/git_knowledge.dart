import '../../../security/security_level.dart';
import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';

/// Knowledge about the `git` version-control tool and its sub-commands.
final class GitKnowledge implements CommandKnowledgePlugin {
  /// Creates the git knowledge plugin.
  const GitKnowledge();

  @override
  String get name => 'git';

  @override
  List<CommandKnowledge> get entries => const [
    CommandKnowledge(
      executable: 'git',
      category: KnowledgeCategory.versionControl,
      description: 'Distributed version-control system.',
      // Read-only is the safe default for unrecognised sub-commands (log,
      // status, diff, show, blame, …).
      baseCapabilities: {CommandCapability.readFilesystem},
      subcommands: [
        SubcommandRule(
          {'push'},
          {CommandCapability.networkWrite},
          description: 'Uploads commits to a remote.',
        ),
        SubcommandRule(
          {'send-email'},
          {CommandCapability.networkWrite},
          description: 'Sends patches over email.',
        ),
        SubcommandRule(
          {'pull', 'clone', 'fetch', 'remote', 'submodule'},
          {CommandCapability.networkRead},
          description: 'Downloads objects or refs from a remote.',
        ),
        SubcommandRule(
          {
            'commit',
            'add',
            'init',
            'checkout',
            'switch',
            'merge',
            'reset',
            'rebase',
            'stash',
            'tag',
            'apply',
            'rm',
            'mv',
            'restore',
            'clean',
            'worktree',
            'bisect',
            'cherry-pick',
            'revert',
            'gc',
            'reflog',
            'am',
            'format-patch',
          },
          {CommandCapability.writeFilesystem},
          description: 'Modifies the working tree or repository.',
        ),
      ],
      argumentRules: [
        ArgumentRule(
          ArgPredicate(_isForcedPush),
          // Capabilities already come from the `push` sub-command rule; this
          // rule only elevates the risk hint.
          {CommandCapability.networkWrite},
          risk: SecurityLevel.mediumRisk,
          description: 'A force push can overwrite remote history.',
        ),
      ],
    ),
  ];
}

/// Whether the arguments describe `git push … --force` (or `-f`/`--force-with-lease`).
bool _isForcedPush(List<String> args) {
  final firstNonFlag = args.cast<String?>().firstWhere(
    (a) => a != null && !a.startsWith('-'),
    orElse: () => null,
  );
  if (firstNonFlag != 'push') return false;
  return args.any(
    (a) => a == '-f' || a == '--force' || a.startsWith('--force-with-lease'),
  );
}
