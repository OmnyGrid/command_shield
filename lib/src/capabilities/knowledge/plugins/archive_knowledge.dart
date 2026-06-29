import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';

/// Knowledge about archive and bundling tools.
///
/// These both read inputs and write outputs, so they carry read + write
/// filesystem capabilities; extraction-only or list-only modes are still
/// conservatively reported as read + write. Single-stream compressors live in
/// the compression plugin.
final class ArchiveKnowledge implements CommandKnowledgePlugin {
  /// Creates the archive knowledge plugin.
  const ArchiveKnowledge();

  @override
  String get name => 'archive';

  @override
  List<CommandKnowledge> get entries => [
    for (final tool in const [
      'tar',
      '7z',
      '7za',
      '7zr',
      'cpio',
      'ar',
      'pax',
      'rar',
      'unrar',
      'unar',
      'lha',
      'arj',
      'zoo',
      'cabextract',
      'rpm2cpio',
      'dpkg-deb',
      'jar',
      'genisoimage',
      'mkisofs',
      'xorriso',
    ])
      CommandKnowledge(
        executable: tool,
        category: KnowledgeCategory.archive,
        description: 'Archive/bundling tool (reads inputs, writes outputs).',
        baseCapabilities: const {
          CommandCapability.readFilesystem,
          CommandCapability.writeFilesystem,
        },
      ),
  ];
}
