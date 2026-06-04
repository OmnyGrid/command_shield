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
      final hit = _findDestructive(context, tokens);
      if (hit == null) continue;
      findings.add(_classify(hit.command, hit.args));
    }
    return findings;
  }

  _Hit? _findDestructive(SecurityContext context, List<String> tokens) {
    for (var i = 0; i < tokens.length; i++) {
      final raw = tokens[i];
      final norm = context.normalizer.normalize(raw).toLowerCase();
      if (CommandFamilies.destructive.contains(norm)) {
        return _Hit(norm, tokens.sublist(i + 1));
      }
      // Skip wrapper commands (sudo, env, ...) and their option flags so we can
      // look *through* them. As soon as we reach a concrete program that is not
      // a wrapper, stop: a destructive name appearing later is just an argument
      // value (e.g. `echo rm`), not the program being executed.
      if (raw.startsWith('-')) continue;
      if (_wrappers.contains(norm)) continue;
      return null;
    }
    return null;
  }

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
