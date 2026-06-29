import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about interactive text editors.
///
/// Editors open files for reading and can write them back, so they carry
/// read + write filesystem capabilities.
final class EditorKnowledge implements CommandKnowledgePlugin {
  /// Creates the editor knowledge plugin.
  const EditorKnowledge();

  @override
  String get name => 'editor';

  static const _ed = KnowledgeCategory.editor;

  @override
  List<CommandKnowledge> get entries => [
    ...simpleEntries(
      const [
        'vim',
        'vi',
        'nvim',
        'neovim',
        'vimdiff',
        'gvim',
        'view',
        'nano',
        'emacs',
        'ed',
        'ex',
        'pico',
        'joe',
        'micro',
        // GUI / modern editors (can open, edit and run files)
        'code',
        'code-insiders',
        'codium',
        'subl',
        'sublime_text',
        'atom',
        'gedit',
        'kate',
        'kwrite',
        'mousepad',
        'notepad',
        'notepad++',
        'helix',
        'hx',
        'kak',
        'kakoune',
      ],
      _ed,
      const {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
      },
    ),

    // Documentation viewers (read-only).
    ...simpleEntries(
      const ['man', 'info', 'apropos', 'whatis', 'cheat'],
      _ed,
      const {CommandCapability.readFilesystem},
    ),
  ];
}
