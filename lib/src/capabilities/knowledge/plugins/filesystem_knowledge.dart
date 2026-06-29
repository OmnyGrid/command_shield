import '../../../security/security_level.dart';
import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about filesystem inspection and manipulation commands.
final class FilesystemKnowledge implements CommandKnowledgePlugin {
  /// Creates the filesystem knowledge plugin.
  const FilesystemKnowledge();

  @override
  String get name => 'filesystem';

  static const _fs = KnowledgeCategory.filesystem;

  @override
  List<CommandKnowledge> get entries => [
    // --- read-only inspection ---
    ...simpleEntries(
      const [
        'ls',
        'cat',
        'head',
        'tail',
        'grep',
        'egrep',
        'fgrep',
        'pwd',
        'echo',
        'stat',
        'file',
        'wc',
        'less',
        'more',
        'which',
        'whereis',
        'whoami',
        'hostname',
        'date',
        'tree',
        'dir',
        'type',
        'sort',
        'uniq',
        'diff',
        'cmp',
        'dirname',
        'basename',
        'realpath',
        'readlink',
        'getconf',
        'id',
        'uname',
        'df',
        'du',
        'lsblk',
        'get-childitem',
        'get-content',
        'gci',
        'cut',
        'awk',
        'column',
        'fold',
        'nl',
        'tac',
        'strings',
      ],
      _fs,
      const {CommandCapability.readFilesystem},
    ),

    // --- write ---
    ...simpleEntries(
      const [
        'touch',
        'mkdir',
        'cp',
        'copy',
        'tee',
        'truncate',
        'ln',
        'install',
        'patch',
        'xcopy',
        'robocopy',
        'set-content',
        'add-content',
        'split',
      ],
      _fs,
      const {CommandCapability.writeFilesystem},
    ),

    // --- delete ---
    ...simpleEntries(
      const [
        'rm',
        'rmdir',
        'del',
        'erase',
        'unlink',
        'shred',
        'remove-item',
        'ri',
      ],
      _fs,
      const {CommandCapability.deleteFilesystem},
    ),

    // --- special cases ---
    CommandKnowledge(
      executable: 'dd',
      category: _fs,
      description: 'Low-level copy/convert of files and devices.',
      baseCapabilities: const {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
      },
      // Writing directly to a block device (`of=/dev/...`) can destroy a disk.
      refine: (args, match) {
        if (args.any((a) => a.toLowerCase().startsWith('of=/dev/'))) {
          match.add(CommandCapability.systemConfiguration);
          match.raiseRisk(SecurityLevel.critical);
          match.note('Writes directly to a block device.');
        }
      },
    ),
    for (final mv in const ['mv', 'move'])
      CommandKnowledge(
        executable: mv,
        category: _fs,
        description: 'Moves or renames files (write + delete of the source).',
        baseCapabilities: const {
          CommandCapability.writeFilesystem,
          CommandCapability.deleteFilesystem,
        },
      ),
    const CommandKnowledge(
      executable: 'sed',
      category: _fs,
      description: 'Stream editor; `-i` edits files in place.',
      baseCapabilities: {CommandCapability.readFilesystem},
      argumentRules: [
        ArgumentRule(
          PrefixFlag({'-i', '--in-place'}),
          {CommandCapability.writeFilesystem},
          description: 'In-place edit writes to the input file.',
        ),
      ],
    ),
    const CommandKnowledge(
      executable: 'find',
      category: _fs,
      description: 'Recursively searches the filesystem.',
      baseCapabilities: {CommandCapability.readFilesystem},
      argumentRules: [
        ArgumentRule(
          TokenPresent({'-delete'}),
          {CommandCapability.deleteFilesystem},
          description: '`-delete` removes matched entries.',
        ),
        ArgumentRule(
          TokenPresent({'-exec', '-execdir'}),
          {CommandCapability.executePrograms},
          description: '`-exec` runs a program per match.',
        ),
      ],
    ),
  ];
}
