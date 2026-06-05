import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about checksum and digest tools.
///
/// These read file contents (or stdin) to compute a digest and print it; they
/// do not modify the files they hash, so they carry only the read capability.
final class HashKnowledge implements CommandKnowledgePlugin {
  /// Creates the hash knowledge plugin.
  const HashKnowledge();

  @override
  String get name => 'hash';

  @override
  List<CommandKnowledge> get entries => simpleEntries(
    const [
      'md5',
      'md5sum',
      'sha1',
      'sha1sum',
      'sha224sum',
      'sha256',
      'sha256sum',
      'sha384sum',
      'sha512sum',
      'shasum',
      'b2sum',
      'cksum',
      'sum',
      'get-filehash',
    ],
    KnowledgeCategory.hash,
    const {CommandCapability.readFilesystem},
  );
}
