import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about Windows-specific commands: `cmd` builtins, PowerShell
/// cmdlets and system tools.
///
/// Cross-platform Windows aliases that already appear in other plugins (`del`,
/// `copy`, `move`, `xcopy`, `robocopy`, `dir`, `type`, `reg`, `netsh`,
/// `set-itemproperty`, …) are owned by those plugins; this plugin adds the
/// commands unique to Windows.
final class WindowsKnowledge implements CommandKnowledgePlugin {
  /// Creates the Windows knowledge plugin.
  const WindowsKnowledge();

  @override
  String get name => 'windows';

  static const _win = {CommandPlatform.windows};

  @override
  List<CommandKnowledge> get entries => [
    // --- read-only inspection ---
    ...simpleEntries(
      const [
        'where',
        'findstr',
        'systeminfo',
        'ver',
        'get-item',
        'get-itemproperty',
        'select-string',
      ],
      KnowledgeCategory.filesystem,
      const {CommandCapability.readFilesystem},
      platforms: _win,
    ),

    // --- system configuration ---
    ...simpleEntries(
      const [
        'sc',
        'icacls',
        'takeown',
        'attrib',
        'wmic',
        'bcdedit',
        'cacls',
        'set-service',
        'new-item',
        'set-localuser',
      ],
      KnowledgeCategory.system,
      const {CommandCapability.systemConfiguration},
      platforms: _win,
    ),

    // --- process management ---
    ...simpleEntries(
      const ['wevtutil'],
      KnowledgeCategory.process,
      const {CommandCapability.processManagement},
      platforms: _win,
    ),
  ];
}
