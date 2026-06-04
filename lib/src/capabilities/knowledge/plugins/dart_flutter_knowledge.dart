import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';

/// Knowledge about the Dart and Flutter command-line tools.
final class DartFlutterKnowledge implements CommandKnowledgePlugin {
  /// Creates the Dart/Flutter knowledge plugin.
  const DartFlutterKnowledge();

  @override
  String get name => 'dartFlutter';

  // Both `dart` and `flutter` execute code by default (run/test/compile/build).
  static const _subcommands = [
    SubcommandRule(
      {'pub', 'packages'},
      {CommandCapability.networkRead, CommandCapability.writeFilesystem},
      description: 'Resolves and downloads package dependencies.',
    ),
    SubcommandRule(
      {'format', 'fix'},
      {CommandCapability.writeFilesystem},
      description: 'Rewrites source files.',
    ),
    SubcommandRule(
      {'run', 'test', 'compile', 'build', 'analyze', 'create'},
      {CommandCapability.executePrograms},
      description: 'Runs or builds Dart/Flutter code.',
    ),
  ];

  static const _argumentRules = [
    ArgumentRule(
      ArgPredicate(_isPubPublish),
      {CommandCapability.networkWrite},
      description: '`pub publish` uploads a package to pub.dev.',
    ),
  ];

  @override
  List<CommandKnowledge> get entries => const [
    CommandKnowledge(
      executable: 'dart',
      category: KnowledgeCategory.interpreter,
      description: 'Dart SDK command-line tool.',
      baseCapabilities: {CommandCapability.executePrograms},
      subcommands: _subcommands,
      argumentRules: _argumentRules,
    ),
    CommandKnowledge(
      executable: 'flutter',
      category: KnowledgeCategory.interpreter,
      description: 'Flutter SDK command-line tool.',
      baseCapabilities: {CommandCapability.executePrograms},
      subcommands: _subcommands,
      argumentRules: _argumentRules,
    ),
  ];

  static bool _isPubPublish(List<String> args) {
    final nonFlags = args.where((a) => !a.startsWith('-')).toList();
    return nonFlags.length >= 2 &&
        (nonFlags[0] == 'pub' || nonFlags[0] == 'packages') &&
        nonFlags[1] == 'publish';
  }
}
