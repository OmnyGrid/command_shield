import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about encryption, signing and encoding tools.
final class CryptoKnowledge implements CommandKnowledgePlugin {
  /// Creates the crypto knowledge plugin.
  const CryptoKnowledge();

  @override
  String get name => 'crypto';

  static const _crypto = KnowledgeCategory.crypto;

  @override
  List<CommandKnowledge> get entries => [
    // openssl reads/writes files; the s_client/s_server/ocsp commands talk to
    // the network.
    const CommandKnowledge(
      executable: 'openssl',
      category: _crypto,
      description: 'Cryptography toolkit (keys, certs, encryption, TLS).',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
      },
      subcommands: [
        SubcommandRule(
          {'s_client', 's_server', 'ocsp'},
          {CommandCapability.networkRead, CommandCapability.networkWrite},
          description: 'Opens a network connection to a TLS/OCSP endpoint.',
        ),
      ],
    ),

    // gpg reads/writes files; keyserver operations talk to the network.
    for (final g in const ['gpg', 'gpg2'])
      CommandKnowledge(
        executable: g,
        category: _crypto,
        description: 'OpenPGP encryption and signing tool.',
        baseCapabilities: const {
          CommandCapability.readFilesystem,
          CommandCapability.writeFilesystem,
        },
        argumentRules: const [
          ArgumentRule(
            ExactFlag({
              '--recv-keys',
              '--send-keys',
              '--refresh-keys',
              '--keyserver',
            }),
            {CommandCapability.networkRead, CommandCapability.networkWrite},
            description: 'Keyserver operations transfer keys over the network.',
          ),
        ],
      ),

    // base64/base32 read an input file (or stdin) and write the result to
    // stdout.
    ...simpleEntries(
      const ['base64', 'base32'],
      _crypto,
      const {CommandCapability.readFilesystem},
    ),
  ];
}
