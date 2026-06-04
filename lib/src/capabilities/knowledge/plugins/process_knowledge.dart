import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about process inspection and control commands.
final class ProcessKnowledge implements CommandKnowledgePlugin {
  /// Creates the process knowledge plugin.
  const ProcessKnowledge();

  @override
  String get name => 'process';

  @override
  List<CommandKnowledge> get entries => simpleEntries(
    const [
      'kill',
      'killall',
      'pkill',
      'ps',
      'top',
      'htop',
      'renice',
      'taskkill',
      'tasklist',
      'get-process',
      'stop-process',
      'pgrep',
      'jobs',
      'bg',
      'fg',
      'wait',
    ],
    KnowledgeCategory.process,
    const {CommandCapability.processManagement},
  );
}
