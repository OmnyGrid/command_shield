import '../../../security/security_level.dart';
import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about network clients, transfer tools and cloud CLIs.
final class NetworkKnowledge implements CommandKnowledgePlugin {
  /// Creates the network knowledge plugin.
  const NetworkKnowledge();

  @override
  String get name => 'network';

  static const _net = KnowledgeCategory.network;

  @override
  List<CommandKnowledge> get entries => [
    // --- network read clients ---
    ...simpleEntries(
      const [
        'ftp',
        'sftp',
        'telnet',
        'ping',
        'dig',
        'nslookup',
        'host',
        'whois',
        'traceroute',
        'aria2c',
        'invoke-webrequest',
        'iwr',
        'invoke-restmethod',
        'irm',
      ],
      _net,
      const {CommandCapability.networkRead},
    ),

    // --- curl / wget: read by default, write when uploading ---
    for (final c in const ['curl', 'wget'])
      CommandKnowledge(
        executable: c,
        category: _net,
        description: 'Transfers data to or from a server.',
        baseCapabilities: const {CommandCapability.networkRead},
        argumentRules: const [
          ArgumentRule(
            ArgPredicate(_hasUploadFlag),
            {CommandCapability.networkWrite},
            description: 'Upload/POST flags send data to the server.',
          ),
        ],
      ),

    // --- bidirectional transfer ---
    for (final c in const ['scp', 'rsync'])
      CommandKnowledge(
        executable: c,
        category: _net,
        description: 'Copies files to/from a remote host.',
        baseCapabilities: const {
          CommandCapability.networkRead,
          CommandCapability.networkWrite,
          CommandCapability.readFilesystem,
        },
      ),
    for (final c in const ['nc', 'ncat'])
      CommandKnowledge(
        executable: c,
        category: _net,
        description: 'Reads and writes raw network connections.',
        baseCapabilities: const {
          CommandCapability.networkRead,
          CommandCapability.networkWrite,
        },
      ),
    const CommandKnowledge(
      executable: 'ssh',
      category: _net,
      description: 'Secure shell; can run a remote command.',
      baseCapabilities: {
        CommandCapability.networkRead,
        CommandCapability.networkWrite,
      },
      argumentRules: [
        ArgumentRule(
          ArgPredicate(_sshHasRemoteCommand),
          {CommandCapability.executePrograms},
          description: 'A trailing command runs a program on the remote host.',
        ),
      ],
    ),

    // --- major cloud CLIs: light destructive-token risk elevation ---
    for (final c in const ['aws', 'gcloud', 'az'])
      CommandKnowledge(
        executable: c,
        category: _net,
        description: 'Cloud platform CLI (network access; may run actions).',
        baseCapabilities: const {
          CommandCapability.networkRead,
          CommandCapability.networkWrite,
        },
        argumentRules: const [
          ArgumentRule(
            TokenPresent({
              'rm',
              'delete',
              'rb',
              'destroy',
              'remove',
              'terminate-instances',
            }),
            {CommandCapability.networkWrite},
            risk: SecurityLevel.mediumRisk,
            description: 'Deletes/terminates a cloud resource.',
          ),
        ],
      ),

    // --- other cloud / platform CLIs (network + can run remote actions) ---
    for (final c in const [
      'gh',
      'helm',
      'doctl',
      'flyctl',
      'fly',
      'heroku',
      'vercel',
      'netlify',
      'wrangler',
      'supabase',
      'firebase',
      'gsutil',
      'bq',
      'eksctl',
      's3cmd',
      'linode-cli',
      'ibmcloud',
      'oci',
      'scw',
      'civo',
      'railway',
    ])
      CommandKnowledge(
        executable: c,
        category: _net,
        description: 'Cloud/platform CLI (network access; may run actions).',
        baseCapabilities: const {
          CommandCapability.networkRead,
          CommandCapability.networkWrite,
        },
      ),

    // --- object-store / sync clients (network both ways + local files) ---
    for (final c in const ['rclone', 'mc'])
      CommandKnowledge(
        executable: c,
        category: _net,
        description: 'Object-storage sync client.',
        baseCapabilities: const {
          CommandCapability.networkRead,
          CommandCapability.networkWrite,
          CommandCapability.readFilesystem,
        },
      ),

    // --- read-only network inspection / diagnostics ---
    ...simpleEntries(
      const [
        'ip',
        'ss',
        'netstat',
        'ifconfig',
        'route',
        'arp',
        'arping',
        'tcpdump',
        'tshark',
        'nmap',
        'masscan',
        'mtr',
        'nmcli',
        'resolvectl',
        'getent',
        'ethtool',
        'iw',
        'iwconfig',
      ],
      _net,
      const {CommandCapability.networkRead},
    ),

    // --- raw transfer / tunneling ---
    for (final c in const ['socat', 'lftp'])
      CommandKnowledge(
        executable: c,
        category: _net,
        description: 'Raw network transfer/relay tool.',
        baseCapabilities: const {
          CommandCapability.networkRead,
          CommandCapability.networkWrite,
        },
      ),
    ...simpleEntries(
      const ['mosh', 'autossh', 'sshpass'],
      _net,
      const {CommandCapability.networkRead, CommandCapability.networkWrite},
    ),
    const CommandKnowledge(
      executable: 'ssh-copy-id',
      category: _net,
      description: 'Installs your public key on a remote host.',
      baseCapabilities: {CommandCapability.networkWrite},
    ),
    const CommandKnowledge(
      executable: 'ssh-keyscan',
      category: _net,
      description: 'Collects host keys from remote servers.',
      baseCapabilities: {CommandCapability.networkRead},
    ),

    // --- VPN / overlay networks (reconfigure networking) ---
    ...simpleEntries(
      const ['tailscale', 'zerotier-cli', 'wg-quick'],
      _net,
      const {
        CommandCapability.networkWrite,
        CommandCapability.systemConfiguration,
      },
    ),
    const CommandKnowledge(
      executable: 'wg',
      category: _net,
      description: 'Configures WireGuard interfaces.',
      baseCapabilities: {CommandCapability.systemConfiguration},
    ),
    for (final c in const ['http', 'https', 'httpie', 'xh'])
      CommandKnowledge(
        executable: c,
        category: _net,
        description: 'HTTP client.',
        baseCapabilities: const {CommandCapability.networkRead},
        argumentRules: const [
          ArgumentRule(
            ArgPredicate(_httpieHasBody),
            {CommandCapability.networkWrite},
            description: 'A request body or non-GET method sends data.',
          ),
        ],
      ),
  ];

  static bool _hasUploadFlag(List<String> args) => args.any(
    (a) =>
        a == '-d' ||
        a == '--data' ||
        a == '-F' ||
        a == '--form' ||
        a == '-T' ||
        a == '--upload-file' ||
        a == '--data-binary' ||
        a == '-X' ||
        a == '--request',
  );

  static bool _sshHasRemoteCommand(List<String> args) =>
      args.where((a) => !a.startsWith('-')).length > 1;

  static bool _httpieHasBody(List<String> args) => args.any(
    (a) =>
        a == 'POST' ||
        a == 'PUT' ||
        a == 'PATCH' ||
        a == 'DELETE' ||
        a.contains('=') ||
        a.startsWith('@'),
  );
}
