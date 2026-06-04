import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';

/// Knowledge about container engines and orchestration tools.
final class ContainerKnowledge implements CommandKnowledgePlugin {
  /// Creates the container knowledge plugin.
  const ContainerKnowledge();

  @override
  String get name => 'container';

  @override
  List<CommandKnowledge> get entries => [
    for (final c in const ['docker', 'podman', 'nerdctl'])
      CommandKnowledge(
        executable: c,
        category: KnowledgeCategory.container,
        description: 'Container engine.',
        subcommands: const [
          SubcommandRule(
            {'push'},
            {CommandCapability.networkWrite},
            description: 'Uploads an image to a registry.',
          ),
          SubcommandRule(
            {'pull', 'run', 'build', 'login', 'create', 'start', 'exec'},
            {CommandCapability.networkRead, CommandCapability.executePrograms},
            description: 'Pulls images and/or runs containers.',
          ),
        ],
      ),
    const CommandKnowledge(
      executable: 'docker-compose',
      category: KnowledgeCategory.container,
      description: 'Multi-container orchestration.',
      baseCapabilities: {
        CommandCapability.networkRead,
        CommandCapability.executePrograms,
      },
    ),
  ];
}
