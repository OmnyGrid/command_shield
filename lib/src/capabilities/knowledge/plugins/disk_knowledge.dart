import '../../../security/security_level.dart';
import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';

/// Knowledge about storage, partitioning and secure-erase tools.
///
/// These commands can irrecoverably destroy data on a filesystem or block
/// device, so — unlike most entries — they carry a non-`safe` base risk. The
/// disk-format and whole-disk-wipe tools are rated [SecurityLevel.critical];
/// partitioners and secure-delete tools are [SecurityLevel.highRisk]. Several
/// are *also* covered structurally by `DestructiveCommandDetector` /
/// `CommandFamilies` so they are blocked by the default shield even through a
/// wrapper such as `sudo` (KB risk alone only blocks when a consumer enables
/// `KnowledgeRiskDetector`).
final class DiskKnowledge implements CommandKnowledgePlugin {
  /// Creates the disk knowledge plugin.
  const DiskKnowledge();

  @override
  String get name => 'disk';

  static const _sys = KnowledgeCategory.system;

  static const _formatCaps = <CommandCapability>{
    CommandCapability.writeFilesystem,
    CommandCapability.deleteFilesystem,
    CommandCapability.systemConfiguration,
  };

  static const _partitionCaps = <CommandCapability>{
    CommandCapability.writeFilesystem,
    CommandCapability.systemConfiguration,
  };

  @override
  List<CommandKnowledge> get entries => [
    // --- make-filesystem / wipe-signatures: no safe form ---
    for (final c in const [
      'mkfs',
      'mke2fs',
      'mkfs.ext2',
      'mkfs.ext3',
      'mkfs.ext4',
      'mkfs.xfs',
      'mkfs.btrfs',
      'mkfs.vfat',
      'mkfs.fat',
      'mkfs.exfat',
      'mkfs.ntfs',
      'mkswap',
      'wipefs',
    ])
      CommandKnowledge(
        executable: c,
        category: _sys,
        description: 'Creates a filesystem / wipes signatures on a device.',
        baseCapabilities: _formatCaps,
        baseRisk: SecurityLevel.critical,
        platforms: const {CommandPlatform.linux},
      ),

    // --- partitioners (interactive; scripted forms are catastrophic) ---
    for (final c in const ['fdisk', 'gdisk', 'sgdisk', 'cfdisk', 'parted'])
      CommandKnowledge(
        executable: c,
        category: _sys,
        description: 'Edits the partition table of a disk.',
        baseCapabilities: _partitionCaps,
        baseRisk: SecurityLevel.highRisk,
        platforms: const {CommandPlatform.linux},
      ),

    // macOS disk utility — refine the erase verbs to critical.
    CommandKnowledge(
      executable: 'diskutil',
      category: _sys,
      description: 'macOS disk utility (partition, format, erase).',
      baseCapabilities: _partitionCaps,
      baseRisk: SecurityLevel.highRisk,
      platforms: const {CommandPlatform.macos},
      refine: (args, match) {
        final verb = args
            .firstWhere((a) => !a.startsWith('-'), orElse: () => '')
            .toLowerCase();
        if (verb.startsWith('erase') ||
            verb == 'reformat' ||
            verb == 'zerodisk' ||
            verb == 'securerase') {
          match.addAll(_formatCaps);
          match.raiseRisk(SecurityLevel.critical);
          match.note('Erases/reformats a disk or volume.');
        }
      },
    ),

    // --- secure delete / device discard ---
    for (final c in const ['srm', 'wipe'])
      CommandKnowledge(
        executable: c,
        category: _sys,
        description: 'Securely deletes files (unrecoverable).',
        baseCapabilities: const {CommandCapability.deleteFilesystem},
        baseRisk: SecurityLevel.highRisk,
        platforms: const {CommandPlatform.linux, CommandPlatform.macos},
      ),
    const CommandKnowledge(
      executable: 'blkdiscard',
      category: _sys,
      description: 'Discards (zeroes) all blocks on a device.',
      baseCapabilities: {
        CommandCapability.deleteFilesystem,
        CommandCapability.systemConfiguration,
      },
      baseRisk: SecurityLevel.critical,
      platforms: {CommandPlatform.linux},
    ),
  ];
}
