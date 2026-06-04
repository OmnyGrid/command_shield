import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';

/// Knowledge about archive and compression tools.
///
/// These both read inputs and write outputs, so they carry read + write
/// filesystem capabilities; extraction-only or list-only modes are still
/// conservatively reported as read + write.
final class ArchiveKnowledge implements CommandKnowledgePlugin {
  /// Creates the archive knowledge plugin.
  const ArchiveKnowledge();

  @override
  String get name => 'archive';

  @override
  List<CommandKnowledge> get entries => [
    for (final tool in const [
      'tar',
      'zip',
      'unzip',
      'gzip',
      'gunzip',
      'bzip2',
      'bunzip2',
      'xz',
      'unxz',
      'zstd',
      '7z',
      '7za',
      'compress',
      'uncompress',
    ])
      CommandKnowledge(
        executable: tool,
        category: KnowledgeCategory.archive,
        description: 'Archive/compression tool (reads inputs, writes outputs).',
        baseCapabilities: const {
          CommandCapability.readFilesystem,
          CommandCapability.writeFilesystem,
        },
      ),
  ];
}
