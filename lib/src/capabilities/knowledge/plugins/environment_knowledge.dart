import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about environment-variable utilities.
///
/// Note: `env` itself lives in the shell plugin because it is also a command
/// wrapper.
final class EnvironmentKnowledge implements CommandKnowledgePlugin {
  /// Creates the environment knowledge plugin.
  const EnvironmentKnowledge();

  @override
  String get name => 'environment';

  @override
  List<CommandKnowledge> get entries => simpleEntries(
    const ['printenv', 'export', 'set', 'setenv'],
    KnowledgeCategory.environment,
    const {CommandCapability.environmentAccess},
  );
}
