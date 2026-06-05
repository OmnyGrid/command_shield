import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';

/// Knowledge about single-stream compressors and zip tools.
///
/// These both read inputs and write outputs, so they carry read + write
/// filesystem capabilities; decompression-only or list-only modes are still
/// conservatively reported as read + write.
final class CompressionKnowledge implements CommandKnowledgePlugin {
  /// Creates the compression knowledge plugin.
  const CompressionKnowledge();

  @override
  String get name => 'compression';

  @override
  List<CommandKnowledge> get entries => [
    for (final tool in const [
      'gzip',
      'gunzip',
      'zcat',
      'zip',
      'unzip',
      'bzip2',
      'bunzip2',
      'bzcat',
      'xz',
      'unxz',
      'xzcat',
      'zstd',
      'unzstd',
      'zstdcat',
      'lz4',
      'lzma',
      'unlzma',
      'compress',
      'uncompress',
      'brotli',
      'pigz',
    ])
      CommandKnowledge(
        executable: tool,
        category: KnowledgeCategory.compression,
        description: 'Compression tool (reads inputs, writes outputs).',
        baseCapabilities: const {
          CommandCapability.readFilesystem,
          CommandCapability.writeFilesystem,
        },
      ),
  ];
}
