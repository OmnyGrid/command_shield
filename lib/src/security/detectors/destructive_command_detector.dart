import '../security_detector.dart';
import '../security_finding.dart';
import '../security_level.dart';

/// Detects destructive deletion commands (`rm`, `rmdir`, `del`, `erase`,
/// `shred`, `unlink`, ...), escalating severity based on flags and targets.
///
/// * A plain deletion is [SecurityLevel.mediumRisk].
/// * Recursive **and** forced deletion is [SecurityLevel.highRisk].
/// * Deletion targeting a filesystem root or critical system path (the classic
///   `rm -rf /`) is [SecurityLevel.critical].
///
/// The detector also looks *through* wrapper commands, so `sudo rm -rf /` is
/// still classified as critical.
final class DestructiveCommandDetector extends SecurityDetector {
  /// Creates the detector.
  const DestructiveCommandDetector();

  @override
  String get code => 'destructive-command';

  static const Set<String> _wrappers = <String>{
    'sudo',
    'su',
    'doas',
    'pkexec',
    'runas',
    'gosu',
    'run0',
    'please',
    'env',
    'xargs',
    'time',
    'nice',
    'nohup',
    'timeout',
    'watch',
    'command',
    'exec',
    'stdbuf',
  };

  @override
  List<SecurityFinding> detect(SecurityContext context) {
    final findings = <SecurityFinding>[];
    for (final inv in context.invocations) {
      final tokens = <String>[inv.executable, ...inv.arguments];
      // `command -v rm` / `command -V mkfs` only resolves the name; it does not
      // run it, so it must not be treated as a destructive invocation.
      if (_isCommandLookup(context, tokens)) continue;
      final eff = _effective(context, tokens);
      if (eff == null) continue;
      final cmd = eff.command;
      final args = eff.args;
      if (CommandFamilies.isDiskDestructive(cmd)) {
        findings.add(_diskFormatFinding(cmd));
      } else if (cmd == 'dd' && _writesToDevice(args)) {
        findings.add(_deviceWriteFinding(cmd));
      } else if (cmd == 'find' && args.contains('-delete')) {
        // `find <path> -delete` removes matched entries — catastrophic when the
        // path is a filesystem root or system directory (`find / -delete`).
        findings.add(_classify(cmd, args));
      } else if (CommandFamilies.destructive.contains(cmd)) {
        findings.add(_classify(cmd, args));
      }
    }
    return findings;
  }

  /// Resolves the concrete program a token list ultimately runs, looking
  /// *through* wrapper commands (`sudo`, `env`, …) and their option flags.
  /// Returns the first non-wrapper executable and the tokens after it, or
  /// `null` if the list is only wrappers/flags. A destructive name appearing
  /// after the effective command is just an argument value (e.g. `echo rm`).
  _Hit? _effective(SecurityContext context, List<String> tokens) {
    for (var i = 0; i < tokens.length; i++) {
      final raw = tokens[i];
      if (raw.startsWith('-')) continue;
      final norm = context.normalizer.normalize(raw).toLowerCase();
      if (_wrappers.contains(norm)) continue;
      return _Hit(norm, tokens.sublist(i + 1));
    }
    return null;
  }

  /// Whether [tokens] is a `command -v`/`-V` (or `builtin command -v`) lookup,
  /// which resolves a name without executing it. Returns true as soon as a
  /// `-v`/`-V` flag is seen while the leading tokens are only `command`/
  /// `builtin`; stops once the target program is reached.
  bool _isCommandLookup(SecurityContext context, List<String> tokens) {
    var sawCommand = false;
    for (final t in tokens) {
      if (t == '-v' || t == '-V') {
        if (sawCommand) return true;
        continue;
      }
      if (t.startsWith('-')) continue;
      final norm = context.normalizer.normalize(t).toLowerCase();
      if (norm == 'command' || norm == 'builtin') {
        sawCommand = true;
        continue;
      }
      return false; // reached the target program
    }
    return false;
  }

  static bool _writesToDevice(List<String> args) =>
      args.any((a) => a.toLowerCase().startsWith('of=/dev/'));

  SecurityFinding _diskFormatFinding(String command) => SecurityFinding(
    level: SecurityLevel.critical,
    message:
        'Disk-format/wipe command "$command" irrecoverably destroys data on '
        'the target filesystem or device.',
    code: code,
  );

  SecurityFinding _deviceWriteFinding(String command) => SecurityFinding(
    level: SecurityLevel.critical,
    message:
        'Command "$command" writes directly to a block device (of=/dev/...), '
        'which can destroy a disk.',
    code: code,
  );

  SecurityFinding _classify(String command, List<String> args) {
    final recursive = args.any(_isRecursiveFlag);
    final force = args.any(_isForceFlag);
    final noPreserveRoot = args.contains('--no-preserve-root');
    final targets = args.where((a) => !a.startsWith('-')).toList();
    final catastrophic = targets.any(_isCatastrophicTarget);

    if (catastrophic) {
      return SecurityFinding(
        level: SecurityLevel.critical,
        message:
            'Destructive command "$command" targets a filesystem root or '
            'critical system path'
            '${noPreserveRoot ? ' with --no-preserve-root' : ''}.',
        code: code,
      );
    }
    if (recursive && force) {
      return SecurityFinding(
        level: SecurityLevel.highRisk,
        message:
            'Recursive, forced deletion via "$command" can remove entire '
            'directory trees.',
        code: code,
      );
    }
    if (recursive) {
      return SecurityFinding(
        level: SecurityLevel.highRisk,
        message: 'Recursive deletion via "$command".',
        code: code,
      );
    }
    return SecurityFinding(
      level: SecurityLevel.mediumRisk,
      message: 'Destructive command "$command" deletes files.',
      code: code,
    );
  }

  static bool _isRecursiveFlag(String arg) {
    if (arg == '--recursive') return true;
    if (arg.toLowerCase() == '/s') return true; // Windows del /s
    if (arg.startsWith('--')) return false;
    return arg.startsWith('-') && RegExp('[rR]').hasMatch(arg);
  }

  static bool _isForceFlag(String arg) {
    if (arg == '--force') return true;
    if (arg.toLowerCase() == '/f' || arg.toLowerCase() == '/q') return true;
    if (arg.startsWith('--')) return false;
    return arg.startsWith('-') && arg.contains('f');
  }

  static final RegExp _homeVar = RegExp(r'^\$\{?HOME\}?[\\/]?\*?$');
  static final RegExp _winVar = RegExp(
    r'^%(USERPROFILE|SYSTEMROOT|HOMEPATH|WINDIR|SYSTEMDRIVE)%[\\/]?\*?$',
    caseSensitive: false,
  );
  static final RegExp _winRoot = RegExp(r'^[A-Za-z]:[\\/]?\*?$');
  static final RegExp _devNode = RegExp(
    r'^/dev/(sd|hd|vd|xvd|nvme|mmcblk|disk|loop|md|dm-)',
  );

  static const Set<String> _systemDirs = <String>{
    '/etc',
    '/bin',
    '/sbin',
    '/usr',
    '/var',
    '/boot',
    '/lib',
    '/lib64',
    '/sys',
    '/proc',
    '/dev',
    '/system',
    '/users',
    '/home',
    '/root',
    '/opt',
    '/library',
    '/applications',
  };

  static bool _isCatastrophicTarget(String target) {
    final s = target.trim();
    if (s.isEmpty) return false;
    const exact = <String>{'/', '/*', '/.', '~', '~/', '/~'};
    if (exact.contains(s)) return true;
    if (_homeVar.hasMatch(s)) return true;
    if (_winVar.hasMatch(s)) return true;
    if (_winRoot.hasMatch(s)) return true;
    final lower = s.toLowerCase();
    if (_devNode.hasMatch(lower)) return true;
    for (final dir in _systemDirs) {
      if (lower == dir || lower == '$dir/' || lower.startsWith('$dir/*')) {
        return true;
      }
    }
    return false;
  }
}

class _Hit {
  _Hit(this.command, this.args);

  final String command;
  final List<String> args;
}
