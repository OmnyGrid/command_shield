import '../../../security/security_level.dart';
import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about commands that change system or security configuration.
final class SystemConfigKnowledge implements CommandKnowledgePlugin {
  /// Creates the system-configuration knowledge plugin.
  const SystemConfigKnowledge();

  @override
  String get name => 'system';

  static const _sys = KnowledgeCategory.system;

  @override
  List<CommandKnowledge> get entries => [
    // --- ownership/permission tools: recursive changes to a system root are
    // a classic foot-gun (`chmod -R 777 /`) ---
    for (final c in const ['chmod', 'chown', 'chgrp'])
      CommandKnowledge(
        executable: c,
        category: _sys,
        description: 'Changes file permissions/ownership.',
        baseCapabilities: const {CommandCapability.systemConfiguration},
        refine: _recursiveOnSystemRoot,
      ),

    // --- routine configuration (no inherent risk hint) ---
    ...simpleEntries(
      const [
        'chattr',
        'mount',
        'umount',
        'useradd',
        'userdel',
        'usermod',
        'groupadd',
        'groupdel',
        'groupmod',
        'gpasswd',
        'passwd',
        'chsh',
        'chfn',
        'service',
        'launchctl',
        'setfacl',
        'setcap',
        'getcap',
        'semanage',
        'restorecon',
        'sysctl',
        'reg',
        'netsh',
        'defaults',
        'crontab',
        'iptables',
        'ip6tables',
        'nft',
        'ufw',
        'firewall-cmd',
        'set-itemproperty',
        'new-service',
        'set-acl',
        'setx',
      ],
      _sys,
      const {CommandCapability.systemConfiguration},
    ),

    // systemctl: queries are read-only; state changes touch system config.
    const CommandKnowledge(
      executable: 'systemctl',
      category: _sys,
      description: 'Controls the systemd service manager.',
      baseCapabilities: {CommandCapability.readFilesystem},
      subcommands: [
        SubcommandRule(
          {
            'status',
            'show',
            'list-units',
            'list-unit-files',
            'list-dependencies',
            'is-active',
            'is-enabled',
            'is-failed',
            'cat',
            'get-default',
            'show-environment',
          },
          {CommandCapability.readFilesystem},
          description: 'Queries unit/system state.',
        ),
        SubcommandRule(
          {
            'start',
            'stop',
            'restart',
            'reload',
            'reload-or-restart',
            'enable',
            'disable',
            'mask',
            'unmask',
            'set-default',
            'daemon-reload',
            'daemon-reexec',
            'isolate',
            'kill',
            'set-property',
            'edit',
            'revert',
            'preset',
          },
          {
            CommandCapability.systemConfiguration,
            CommandCapability.processManagement,
          },
          risk: SecurityLevel.lowRisk,
          description: 'Changes service/unit state.',
        ),
        SubcommandRule(
          {
            'poweroff',
            'reboot',
            'halt',
            'suspend',
            'hibernate',
            'kexec',
            'emergency',
            'rescue',
          },
          {
            CommandCapability.systemConfiguration,
            CommandCapability.processManagement,
          },
          risk: SecurityLevel.highRisk,
          description: 'Powers off or changes the running system target.',
        ),
      ],
    ),

    // --- kernel modules: load/unload code into the running kernel ---
    for (final c in const [
      'modprobe',
      'insmod',
      'rmmod',
      'kextload',
      'kextunload',
    ])
      CommandKnowledge(
        executable: c,
        category: _sys,
        description: 'Loads or unloads a kernel module.',
        baseCapabilities: const {
          CommandCapability.systemConfiguration,
          CommandCapability.executePrograms,
        },
        baseRisk: SecurityLevel.highRisk,
      ),

    // --- power / run-level control ---
    for (final c in const [
      'shutdown',
      'reboot',
      'halt',
      'poweroff',
      'init',
      'telinit',
    ])
      CommandKnowledge(
        executable: c,
        category: _sys,
        description: 'Halts, reboots or changes the system run level.',
        baseCapabilities: const {
          CommandCapability.systemConfiguration,
          CommandCapability.processManagement,
        },
        baseRisk: SecurityLevel.highRisk,
      ),

    // --- privileged security configuration ---
    const CommandKnowledge(
      executable: 'visudo',
      category: _sys,
      description: 'Edits the sudoers policy.',
      baseCapabilities: {CommandCapability.systemConfiguration},
      baseRisk: SecurityLevel.highRisk,
    ),
    const CommandKnowledge(
      executable: 'nvram',
      category: _sys,
      description: 'Reads/writes firmware (NVRAM) variables.',
      baseCapabilities: {CommandCapability.systemConfiguration},
      baseRisk: SecurityLevel.highRisk,
      platforms: {CommandPlatform.macos},
    ),
    const CommandKnowledge(
      executable: 'spctl',
      category: _sys,
      description: 'Manages macOS Gatekeeper assessment policy.',
      baseCapabilities: {CommandCapability.systemConfiguration},
      baseRisk: SecurityLevel.highRisk,
      platforms: {CommandPlatform.macos},
    ),
    // csrutil disable turns off System Integrity Protection — critical.
    CommandKnowledge(
      executable: 'csrutil',
      category: _sys,
      description: 'Configures macOS System Integrity Protection (SIP).',
      baseCapabilities: const {CommandCapability.systemConfiguration},
      baseRisk: SecurityLevel.highRisk,
      platforms: const {CommandPlatform.macos},
      refine: (args, match) {
        if (args.any((a) => a.toLowerCase() == 'disable')) {
          match.raiseRisk(SecurityLevel.critical);
          match.note('Disables System Integrity Protection.');
        }
      },
    ),
  ];
}

/// Raises risk for a recursive permission/ownership change that targets a
/// filesystem root or system directory (`chmod -R 777 /`, `chown -R u /etc`).
void _recursiveOnSystemRoot(List<String> args, KnowledgeMatch match) {
  final recursive = args.any(
    (a) => a == '-R' || a == '-r' || a == '--recursive',
  );
  if (!recursive) return;
  if (args.any((a) => !a.startsWith('-') && _isSystemRoot(a))) {
    match.raiseRisk(SecurityLevel.highRisk);
    match.note('Recursive permission/ownership change on a system root.');
  }
}

const _systemRoots = <String>{
  '/etc',
  '/bin',
  '/sbin',
  '/usr',
  '/var',
  '/boot',
  '/lib',
  '/lib64',
  '/sys',
  '/proc',
  '/dev',
  '/root',
  '/home',
  '/opt',
  '/library',
  '/system',
};

bool _isSystemRoot(String path) {
  final s = path.trim().toLowerCase();
  if (s == '/' || s == '/*') return true;
  for (final d in _systemRoots) {
    if (s == d || s == '$d/' || s.startsWith('$d/')) return true;
  }
  return false;
}
