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

    // --- cloud / platform CLIs (network + can execute remote actions) ---
    for (final c in const ['gh', 'aws', 'gcloud', 'az', 'kubectl', 'helm'])
      CommandKnowledge(
        executable: c,
        category: _net,
        description: 'Cloud/platform CLI (network access; may run actions).',
        baseCapabilities: const {
          CommandCapability.networkRead,
          CommandCapability.networkWrite,
        },
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
