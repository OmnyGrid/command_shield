import '../../../security/security_level.dart';
import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about infrastructure-as-code and configuration-management tools.
///
/// These read local configuration, talk to remote providers/APIs and run
/// actions that provision or mutate real infrastructure. The provisioners are
/// refined per sub-command so that read/plan verbs stay low while
/// apply/destroy verbs escalate.
final class IacKnowledge implements CommandKnowledgePlugin {
  /// Creates the infrastructure-as-code knowledge plugin.
  const IacKnowledge();

  @override
  String get name => 'iac';

  static const _iac = KnowledgeCategory.infrastructure;

  // Terraform/OpenTofu verb rules (also reused by terragrunt).
  static const _tfRead = SubcommandRule(
    {
      'plan',
      'validate',
      'fmt',
      'show',
      'output',
      'providers',
      'version',
      'graph',
      'state',
      'console',
      'get',
      'init',
      'workspace',
    },
    {CommandCapability.readFilesystem, CommandCapability.networkRead},
    description: 'Reads or plans infrastructure.',
  );
  static const _tfApply = SubcommandRule(
    {'apply', 'import', 'taint', 'untaint', 'refresh'},
    {
      CommandCapability.networkWrite,
      CommandCapability.writeFilesystem,
      CommandCapability.executePrograms,
    },
    risk: SecurityLevel.mediumRisk,
    description: 'Provisions or changes real infrastructure.',
  );
  static const _tfDestroy = SubcommandRule(
    {'destroy'},
    {
      CommandCapability.networkWrite,
      CommandCapability.writeFilesystem,
      CommandCapability.executePrograms,
    },
    risk: SecurityLevel.highRisk,
    description: 'Destroys managed infrastructure.',
  );
  static const _autoApprove = ArgumentRule(
    TokenPresent({'-auto-approve', '--auto-approve', '-auto-approve=true'}),
    {},
    risk: SecurityLevel.highRisk,
    description: 'Applies/destroys without an interactive confirmation.',
  );

  @override
  List<CommandKnowledge> get entries => [
    // --- Terraform family (plan stays low; apply/destroy escalate) ---
    for (final c in const ['terraform', 'tofu', 'terragrunt'])
      CommandKnowledge(
        executable: c,
        category: _iac,
        description: 'Infrastructure-as-code provisioner.',
        baseCapabilities: const {
          CommandCapability.readFilesystem,
          CommandCapability.networkRead,
        },
        subcommands: const [_tfRead, _tfApply, _tfDestroy],
        argumentRules: const [_autoApprove],
      ),

    // Pulumi has the same plan/up/destroy shape with different verb names.
    const CommandKnowledge(
      executable: 'pulumi',
      category: _iac,
      description: 'Infrastructure-as-code provisioner.',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.networkRead,
      },
      subcommands: [
        SubcommandRule(
          {'preview', 'stack', 'config', 'about', 'whoami', 'plugin', 'logs'},
          {CommandCapability.readFilesystem, CommandCapability.networkRead},
          description: 'Reads or previews infrastructure.',
        ),
        SubcommandRule(
          {'up', 'import', 'refresh'},
          {
            CommandCapability.networkWrite,
            CommandCapability.writeFilesystem,
            CommandCapability.executePrograms,
          },
          risk: SecurityLevel.mediumRisk,
          description: 'Provisions or changes real infrastructure.',
        ),
        SubcommandRule(
          {'destroy'},
          {
            CommandCapability.networkWrite,
            CommandCapability.writeFilesystem,
            CommandCapability.executePrograms,
          },
          risk: SecurityLevel.highRisk,
          description: 'Destroys managed infrastructure.',
        ),
      ],
    ),

    // packer builds images (downloads, runs builders, writes artifacts).
    const CommandKnowledge(
      executable: 'packer',
      category: _iac,
      description: 'Builds machine/container images.',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.networkRead,
        CommandCapability.networkWrite,
        CommandCapability.executePrograms,
      },
    ),

    // --- configuration management ---
    for (final c in const [
      'ansible',
      'salt',
      'salt-call',
      'puppet',
      'chef-client',
      'knife',
    ])
      CommandKnowledge(
        executable: c,
        category: _iac,
        description: 'Configuration-management tool (configures hosts).',
        baseCapabilities: const {
          CommandCapability.networkRead,
          CommandCapability.networkWrite,
          CommandCapability.executePrograms,
          CommandCapability.systemConfiguration,
        },
      ),

    // ansible-playbook: `--become` escalates privileges on the targets.
    const CommandKnowledge(
      executable: 'ansible-playbook',
      category: _iac,
      description: 'Runs Ansible playbooks against hosts.',
      baseCapabilities: {
        CommandCapability.networkRead,
        CommandCapability.networkWrite,
        CommandCapability.executePrograms,
        CommandCapability.systemConfiguration,
      },
      argumentRules: [
        ArgumentRule(
          TokenPresent({'--become', '-b', '--become-method'}),
          {
            CommandCapability.privilegeEscalation,
            CommandCapability.systemConfiguration,
          },
          risk: SecurityLevel.mediumRisk,
          description: 'Escalates privileges on the managed hosts.',
        ),
      ],
    ),

    // ansible-galaxy downloads roles/collections; ansible-vault edits encrypted
    // files locally.
    const CommandKnowledge(
      executable: 'ansible-galaxy',
      category: _iac,
      description: 'Downloads Ansible roles/collections.',
      baseCapabilities: {
        CommandCapability.networkRead,
        CommandCapability.writeFilesystem,
      },
    ),
    const CommandKnowledge(
      executable: 'ansible-vault',
      category: _iac,
      description: 'Encrypts/decrypts Ansible data files.',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
      },
    ),

    // vault: reads/lists are low; writes/deletes mutate secrets.
    const CommandKnowledge(
      executable: 'vault',
      category: _iac,
      description: 'HashiCorp Vault secrets client.',
      baseCapabilities: {CommandCapability.networkRead},
      subcommands: [
        SubcommandRule(
          {'read', 'list', 'status', 'login', 'token', 'print', 'version'},
          {CommandCapability.networkRead},
          description: 'Reads secrets or status.',
        ),
        SubcommandRule(
          {'write', 'delete', 'kv', 'put', 'patch', 'unwrap', 'destroy'},
          {CommandCapability.networkWrite},
          risk: SecurityLevel.mediumRisk,
          description: 'Writes or deletes secrets/state.',
        ),
      ],
    ),

    // --- service-mesh clients (talk to a server) ---
    ...simpleEntries(
      const ['consul', 'nomad'],
      _iac,
      const {CommandCapability.networkRead, CommandCapability.networkWrite},
    ),
  ];
}
