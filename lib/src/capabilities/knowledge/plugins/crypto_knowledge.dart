import '../../../security/security_level.dart';
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
    // stdout; the same for other encoders.
    ...simpleEntries(
      const [
        'base64',
        'base32',
        'base58',
        'uuencode',
        'uudecode',
        'xxd',
        'qrencode',
        'ssh-add',
      ],
      _crypto,
      const {CommandCapability.readFilesystem},
    ),

    // --- file encryption / signing tools (read input, write output) ---
    ...simpleEntries(
      const [
        'age',
        'rage',
        'minisign',
        'signify',
        'sops',
        'mkcert',
        'keytool',
        'ssh-keygen',
        'pass',
        'gopass',
        'secret-tool',
        'pinentry',
      ],
      _crypto,
      const {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
      },
    ),

    // cosign signs and pushes artifacts to a registry.
    const CommandKnowledge(
      executable: 'cosign',
      category: _crypto,
      description: 'Signs/verifies container artifacts (registry access).',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.networkRead,
        CommandCapability.networkWrite,
      },
    ),

    // step is a smallstep CA client (issue/inspect certs over the network).
    const CommandKnowledge(
      executable: 'step',
      category: _crypto,
      description: 'smallstep certificate toolkit (CA/ACME client).',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
        CommandCapability.networkRead,
      },
    ),

    // certbot obtains certificates and reconfigures the system/web server.
    const CommandKnowledge(
      executable: 'certbot',
      category: _crypto,
      description: 'ACME/Let\'s Encrypt certificate client.',
      baseCapabilities: {
        CommandCapability.networkRead,
        CommandCapability.networkWrite,
        CommandCapability.writeFilesystem,
        CommandCapability.systemConfiguration,
      },
    ),

    // macOS keychain tool — can read/write secrets and change trust settings.
    const CommandKnowledge(
      executable: 'security',
      category: _crypto,
      description: 'macOS keychain and security configuration tool.',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
        CommandCapability.systemConfiguration,
      },
      baseRisk: SecurityLevel.highRisk,
      platforms: {CommandPlatform.macos},
    ),
  ];
}
