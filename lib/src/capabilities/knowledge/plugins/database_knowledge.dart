import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about database clients and dump/restore tools.
final class DatabaseKnowledge implements CommandKnowledgePlugin {
  /// Creates the database knowledge plugin.
  const DatabaseKnowledge();

  @override
  String get name => 'database';

  static const _db = KnowledgeCategory.database;

  @override
  List<CommandKnowledge> get entries => [
    // --- network clients (connect to a database server) ---
    ...simpleEntries(
      const [
        'psql',
        'mysql',
        'mariadb',
        'mongo',
        'mongosh',
        'redis-cli',
        'cqlsh',
        'influx',
      ],
      _db,
      const {CommandCapability.networkRead, CommandCapability.networkWrite},
    ),

    // --- local file database ---
    const CommandKnowledge(
      executable: 'sqlite3',
      category: _db,
      description: 'Operates on a local SQLite database file.',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
      },
    ),

    // --- dump tools: read from the server, write a dump file ---
    for (final d in const ['pg_dump', 'mysqldump'])
      CommandKnowledge(
        executable: d,
        category: _db,
        description: 'Dumps a database to a file (reads server, writes file).',
        baseCapabilities: const {
          CommandCapability.networkRead,
          CommandCapability.writeFilesystem,
        },
      ),

    // --- restore tool: read a dump file, write to the server ---
    const CommandKnowledge(
      executable: 'pg_restore',
      category: _db,
      description: 'Restores a dump file into a database server.',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.networkWrite,
      },
    ),
  ];
}
