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

  // Running a project script or a fetched binary executes arbitrary code.
  static const _scriptRun = SubcommandRule(
    {'run', 'run-script', 'exec', 'start', 'test', 'dlx', 'x', 'create'},
    {CommandCapability.executePrograms},
    description: 'Runs project scripts or fetched binaries (arbitrary code).',
  );

  @override
  List<CommandKnowledge> get entries => [
    // --- JS managers also run project scripts / fetched binaries ---
    for (final c in const ['npm', 'pnpm', 'yarn', 'bun'])
      CommandKnowledge(
        executable: c,
        category: _pm,
        description: 'JavaScript package manager.',
        subcommands: const [_userInstall, _publish, _scriptRun],
      ),
    for (final c in const ['gem', 'composer'])
      CommandKnowledge(
        executable: c,
        category: _pm,
        description: 'Package manager.',
        subcommands: const [_userInstall, _publish],
      ),
    for (final c in const [
      'pip',
      'pip3',
      'pipx',
      'poetry',
      'conda',
      'mamba',
      'micromamba',
      'uv',
      'rye',
      'pdm',
      'hatch',
    ])
      CommandKnowledge(
        executable: c,
        category: _pm,
        description: 'Python package/environment manager.',
        subcommands: const [_userInstall, _publish],
      ),
    // toolchain / runtime version managers (download + install toolchains).
    for (final c in const [
      'rustup',
      'asdf',
      'nvm',
      'fnm',
      'volta',
      'sdkman',
      'pkgx',
      'bundle',
      'bundler',
    ])
      CommandKnowledge(
        executable: c,
        category: _pm,
        description: 'Toolchain / dependency manager.',
        subcommands: const [_userInstall],
      ),
    // twine only uploads packages to a registry.
    const CommandKnowledge(
      executable: 'twine',
      category: _pm,
      description: 'Uploads Python packages to PyPI.',
      baseCapabilities: {CommandCapability.networkWrite},
    ),
    // cargo and go also build and run code, but each has its own informational
    // forms: cargo `-V`, and go's positional `version`/`env` sub-commands
    // (`go env -w K=V` falls through via the non-informational `-w`).
    const CommandKnowledge(
      executable: 'cargo',
      category: _pm,
      description: 'Rust toolchain / package manager.',
      baseCapabilities: {CommandCapability.executePrograms},
      subcommands: [_userInstall, _publish],
      informationalTokens: {'-V'},
    ),
    const CommandKnowledge(
      executable: 'go',
      category: _pm,
      description: 'Go toolchain / package manager.',
      baseCapabilities: {CommandCapability.executePrograms},
      subcommands: [_userInstall, _publish],
      informationalTokens: {'version', 'env'},
    ),

    // --- system managers (also reconfigure the system) ---
    for (final c in const [
      'apt',
      'apt-get',
      'aptitude',
      'dpkg',
      'rpm',
      'brew',
      'port',
      'dnf',
      'yum',
      'pacman',
      'apk',
      'zypper',
      'emerge',
      'nix',
      'nix-env',
      'snap',
      'flatpak',
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
