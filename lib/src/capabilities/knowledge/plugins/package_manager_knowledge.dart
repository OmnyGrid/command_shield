import '../../../security/security_level.dart';
import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';

/// Knowledge about software package managers.
///
/// Installing/updating packages downloads code from the network, writes it to
/// disk and (for system managers) reconfigures the system — and runs arbitrary
/// install scripts, so it is flagged as a medium risk.
final class PackageManagerKnowledge implements CommandKnowledgePlugin {
  /// Creates the package-manager knowledge plugin.
  const PackageManagerKnowledge();

  @override
  String get name => 'packageManager';

  static const _pm = KnowledgeCategory.packageManager;

  // Capabilities for a user-space install (downloads + writes project files).
  static const _userInstall = SubcommandRule(
    {
      'install',
      'i',
      'add',
      'ci',
      'update',
      'upgrade',
      'audit',
      'download',
      'wheel',
      'get',
      'restore',
      'sync',
    },
    {CommandCapability.networkRead, CommandCapability.writeFilesystem},
    risk: SecurityLevel.mediumRisk,
    description: 'Downloads and installs packages (runs install scripts).',
  );

  static const _publish = SubcommandRule(
    {'publish'},
    {CommandCapability.networkWrite},
    description: 'Uploads a package to a registry.',
  );

  @override
  List<CommandKnowledge> get entries => [
    // --- user-space managers ---
    for (final c in const ['npm', 'pnpm', 'yarn', 'gem', 'composer'])
      CommandKnowledge(
        executable: c,
        category: _pm,
        description: 'Package manager.',
        subcommands: const [_userInstall, _publish],
      ),
    for (final c in const ['pip', 'pip3'])
      CommandKnowledge(
        executable: c,
        category: _pm,
        description: 'Python package installer.',
        subcommands: const [_userInstall],
      ),
    for (final c in const ['cargo', 'go'])
      CommandKnowledge(
        executable: c,
        category: _pm,
        description: 'Language toolchain / package manager.',
        // These also build and run code.
        baseCapabilities: const {CommandCapability.executePrograms},
        subcommands: const [_userInstall, _publish],
      ),

    // --- system managers (also reconfigure the system) ---
    for (final c in const [
      'apt',
      'apt-get',
      'brew',
      'dnf',
      'yum',
      'pacman',
      'apk',
      'zypper',
      'choco',
      'winget',
      'scoop',
    ])
      CommandKnowledge(
        executable: c,
        category: _pm,
        description: 'System package manager.',
        subcommands: const [
          SubcommandRule(
            {
              'install',
              'update',
              'upgrade',
              'add',
              'fetch',
              '-s',
              'remove',
              'erase',
              'reinstall',
            },
            {
              CommandCapability.networkRead,
              CommandCapability.writeFilesystem,
              CommandCapability.systemConfiguration,
            },
            risk: SecurityLevel.mediumRisk,
            description: 'Installs/updates system packages.',
          ),
        ],
      ),
  ];
}
