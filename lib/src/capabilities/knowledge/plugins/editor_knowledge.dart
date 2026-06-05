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

  @override
  List<CommandKnowledge> get entries => simpleEntries(
    const [
      'vim',
      'vi',
      'nvim',
      'vimdiff',
      'nano',
      'emacs',
      'ed',
      'ex',
      'pico',
      'joe',
      'micro',
    ],
    KnowledgeCategory.editor,
    const {CommandCapability.readFilesystem, CommandCapability.writeFilesystem},
  );
}
