import '../../../security/security_level.dart';
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

  static const _proc = KnowledgeCategory.process;

  @override
  List<CommandKnowledge> get entries => [
    // `kill` is ordinarily safe, but signalling PID 1 (init) or target -1/0
    // (every process / the whole process group) can take down the system.
    const CommandKnowledge(
      executable: 'kill',
      category: _proc,
      description: 'Sends a signal to a process.',
      baseCapabilities: {CommandCapability.processManagement},
      argumentRules: [
        ArgumentRule(
          ArgPredicate(_killsInitOrEveryProcess),
          {CommandCapability.processManagement},
          risk: SecurityLevel.highRisk,
          description:
              'Signals PID 1 (init) or every process (-1) / the process '
              'group (0), which can crash the system.',
        ),
      ],
    ),

    // `pkill`/`killall` select by name/pattern; a match-all pattern (`.`) or
    // `-u root` signals a huge swath of processes at once.
    for (final c in const ['pkill', 'killall'])
      CommandKnowledge(
        executable: c,
        category: _proc,
        description: 'Signals processes by name/pattern.',
        baseCapabilities: const {CommandCapability.processManagement},
        argumentRules: const [
          ArgumentRule(
            ArgPredicate(_killsBroadly),
            {CommandCapability.processManagement},
            risk: SecurityLevel.highRisk,
            description:
                'A match-all pattern or `-u root` signals a large set of '
                'processes, which can crash the system.',
          ),
        ],
      ),

    ...simpleEntries(
      const [
        'ps',
        'top',
        'htop',
        'btop',
        'atop',
        'glances',
        'iotop',
        'renice',
        'taskkill',
        'tasklist',
        'get-process',
        'stop-process',
        'pgrep',
        'pidof',
        'pstree',
        'pidstat',
        'jobs',
        'bg',
        'fg',
        'wait',
        'lsof',
        'fuser',
        'taskset',
        'ionice',
        'chrt',
        'setsid',
        // hardware / resource inspection
        'vmstat',
        'iostat',
        'mpstat',
        'sar',
        'free',
        'uptime',
        'nproc',
        'lscpu',
        'lsmem',
        'lsusb',
        'lspci',
        'lshw',
        'dmidecode',
      ],
      _proc,
      const {CommandCapability.processManagement},
    ),

    // Kernel/system log readers.
    ...simpleEntries(
      const ['dmesg', 'journalctl', 'last', 'who', 'w'],
      _proc,
      const {CommandCapability.readFilesystem},
    ),
  ];
}

/// Whether a `kill` invocation targets PID 1 (init), every process (`-1`) or
/// the caller's whole process group (`0`).
///
/// Signal specifiers (`-9`, `-KILL`, `-s TERM`, `-n 9`) are skipped so that a
/// normal `kill -9 1234` is not flagged; only `1`/`0` as a target, or `-1`/`-0`
/// appearing *after* a signal, count as catastrophic.
bool _killsInitOrEveryProcess(List<String> args) {
  var signalSeen = false;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '-s' || a == '--signal' || a == '-n') {
      signalSeen = true;
      i++; // skip the signal value
      continue;
    }
    if (a.startsWith('-') && a.length > 1) {
      final body = a.substring(1);
      if (body == '1' || body == '0') {
        // `-1`/`-0` is a target (all processes / process group) when a signal
        // was already given; otherwise treat it as the signal (e.g. SIGHUP).
        if (signalSeen) return true;
        signalSeen = true;
        continue;
      }
      signalSeen = true; // a numeric/named signal such as -9, -KILL, -SIGTERM
      continue;
    }
    // A positional target: PID 1 (init) or 0 (the whole process group).
    if (a == '1' || a == '0' || a == '-1') return true;
  }
  return false;
}

/// Whether a `pkill`/`killall` invocation selects a very broad set of
/// processes: a regex/pattern that matches everything (`.`, `.*`, …) or every
/// process owned by root (`-u root` / `-u 0`).
bool _killsBroadly(List<String> args) {
  const matchAll = {'.', '.*', '.+', '.*?', r'^.*$', r'^.+$'};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if ((a == '-u' || a == '--user') && i + 1 < args.length) {
      final u = args[i + 1];
      if (u == 'root' || u == '0') return true;
      continue;
    }
    if (!a.startsWith('-') && matchAll.contains(a)) return true;
  }
  return false;
}
