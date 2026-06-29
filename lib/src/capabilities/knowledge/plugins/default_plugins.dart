import '../command_knowledge_plugin.dart';
import 'archive_knowledge.dart';
import 'compression_knowledge.dart';
import 'container_knowledge.dart';
import 'crypto_knowledge.dart';
import 'dart_flutter_knowledge.dart';
import 'database_knowledge.dart';
import 'disk_knowledge.dart';
import 'editor_knowledge.dart';
import 'environment_knowledge.dart';
import 'filesystem_knowledge.dart';
import 'git_knowledge.dart';
import 'hash_knowledge.dart';
import 'iac_knowledge.dart';
import 'modern_cli_knowledge.dart';
import 'network_knowledge.dart';
import 'package_manager_knowledge.dart';
import 'process_knowledge.dart';
import 'shell_knowledge.dart';
import 'system_config_knowledge.dart';
import 'vcs_knowledge.dart';
import 'windows_knowledge.dart';

/// The built-in plugins composed by `CommandKnowledgeBase` when no explicit set
/// is supplied (or when `includeDefaults` is left enabled).
///
/// Order matters only for duplicate executable names: later plugins override
/// earlier ones. The list is ordered so that specialised plugins (git,
/// dart/flutter, package managers, containers) come after the generic ones.
const List<CommandKnowledgePlugin> defaultKnowledgePlugins =
    <CommandKnowledgePlugin>[
      FilesystemKnowledge(),
      HashKnowledge(),
      ArchiveKnowledge(),
      CompressionKnowledge(),
      CryptoKnowledge(),
      EditorKnowledge(),
      ModernCliKnowledge(),
      ShellKnowledge(),
      EnvironmentKnowledge(),
      ProcessKnowledge(),
      SystemConfigKnowledge(),
      DiskKnowledge(),
      NetworkKnowledge(),
      DatabaseKnowledge(),
      ContainerKnowledge(),
      IacKnowledge(),
      PackageManagerKnowledge(),
      DartFlutterKnowledge(),
      GitKnowledge(),
      VcsKnowledge(),
      WindowsKnowledge(),
    ];
