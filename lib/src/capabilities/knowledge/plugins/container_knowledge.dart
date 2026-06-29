import '../../../security/security_level.dart';
import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about container engines and orchestration tools.
final class ContainerKnowledge implements CommandKnowledgePlugin {
  /// Creates the container knowledge plugin.
  const ContainerKnowledge();

  @override
  String get name => 'container';

  static const _ct = KnowledgeCategory.container;

  // --- Kubernetes verb rules, shared by kubectl and oc ---
  static const _k8sRead = SubcommandRule(
    {
      'get',
      'describe',
      'logs',
      'top',
      'explain',
      'version',
      'config',
      'cluster-info',
      'api-resources',
      'api-versions',
      'wait',
      'auth',
      'diff',
    },
    {CommandCapability.networkRead},
    description: 'Read-only cluster query.',
  );
  static const _k8sWrite = SubcommandRule(
    {
      'apply',
      'create',
      'patch',
      'replace',
      'edit',
      'scale',
      'label',
      'annotate',
      'rollout',
      'set',
      'expose',
      'autoscale',
      'cordon',
      'uncordon',
      'drain',
      'taint',
    },
    {CommandCapability.networkWrite},
    risk: SecurityLevel.mediumRisk,
    description: 'Mutates cluster state.',
  );
  static const _k8sDelete = SubcommandRule(
    {'delete'},
    {CommandCapability.networkWrite, CommandCapability.deleteFilesystem},
    risk: SecurityLevel.highRisk,
    description: 'Deletes cluster resources.',
  );
  static const _k8sExec = SubcommandRule(
    {'exec', 'attach', 'cp', 'port-forward', 'proxy', 'run'},
    {
      CommandCapability.networkRead,
      CommandCapability.networkWrite,
      CommandCapability.executePrograms,
    },
    risk: SecurityLevel.mediumRisk,
    description: 'Runs a process in / streams to a pod.',
  );

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
          SubcommandRule(
            {'rm', 'rmi', 'prune', 'kill', 'stop'},
            {CommandCapability.deleteFilesystem},
            description: 'Removes containers, images or volumes.',
          ),
        ],
      ),

    // Kubernetes CLIs: read-only by default, escalating per verb.
    for (final c in const ['kubectl', 'oc'])
      CommandKnowledge(
        executable: c,
        category: _ct,
        description: 'Kubernetes/OpenShift cluster CLI.',
        baseCapabilities: const {CommandCapability.networkRead},
        subcommands: const [_k8sRead, _k8sWrite, _k8sDelete, _k8sExec],
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

    // --- image builders / registry clients / runtimes (pull + run code) ---
    ...simpleEntries(
      const [
        'buildah',
        'skopeo',
        'img',
        'kaniko',
        'crictl',
        'ctr',
        'earthly',
        'singularity',
        'apptainer',
      ],
      _ct,
      const {CommandCapability.networkRead, CommandCapability.executePrograms},
    ),

    // --- local cluster / VM managers (run code, manage local state) ---
    ...simpleEntries(
      const ['minikube', 'kind', 'k3d', 'k3s', 'lima', 'colima', 'vagrant'],
      _ct,
      const {CommandCapability.networkRead, CommandCapability.executePrograms},
    ),

    // --- context switchers / TUIs ---
    ...simpleEntries(
      const ['kubectx', 'kubens'],
      _ct,
      const {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
      },
    ),
    ...simpleEntries(
      const ['k9s', 'dive', 'lazydocker'],
      _ct,
      const {CommandCapability.readFilesystem},
    ),
  ];
}
