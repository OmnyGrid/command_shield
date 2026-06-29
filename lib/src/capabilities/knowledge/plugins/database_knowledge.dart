import '../../../security/security_level.dart';
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
        'pgcli',
        'mycli',
        'litecli',
        'usql',
        'clickhouse-client',
        'cockroach',
        'etcdctl',
        'sqlplus',
        'sqlcmd',
        'createdb',
        'createuser',
      ],
      _db,
      const {CommandCapability.networkRead, CommandCapability.networkWrite},
    ),

    // --- destructive admin: dropping a database/user ---
    for (final d in const ['dropdb', 'dropuser'])
      CommandKnowledge(
        executable: d,
        category: _db,
        description: 'Drops a database or role (irreversible).',
        baseCapabilities: const {CommandCapability.networkWrite},
        baseRisk: SecurityLevel.highRisk,
      ),

    // --- local file databases ---
    ...simpleEntries(
      const ['sqlite3', 'duckdb'],
      _db,
      const {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
      },
    ),

    // --- dump/export tools: read from the server, write a file ---
    for (final d in const [
      'pg_dump',
      'pg_dumpall',
      'mysqldump',
      'mongodump',
      'mongoexport',
    ])
      CommandKnowledge(
        executable: d,
        category: _db,
        description: 'Dumps a database to a file (reads server, writes file).',
        baseCapabilities: const {
          CommandCapability.networkRead,
          CommandCapability.writeFilesystem,
        },
      ),

    // --- restore/import tools: read a file, write to the server ---
    for (final d in const ['pg_restore', 'mongorestore', 'mongoimport'])
      CommandKnowledge(
        executable: d,
        category: _db,
        description: 'Restores a dump/data file into a database server.',
        baseCapabilities: const {
          CommandCapability.readFilesystem,
          CommandCapability.networkWrite,
        },
      ),

    // prisma reads schema files, runs migrations and talks to the database.
    const CommandKnowledge(
      executable: 'prisma',
      category: _db,
      description: 'ORM toolkit (migrations, codegen, db access).',
      baseCapabilities: {
        CommandCapability.readFilesystem,
        CommandCapability.writeFilesystem,
        CommandCapability.networkWrite,
        CommandCapability.executePrograms,
      },
    ),
  ];
}
