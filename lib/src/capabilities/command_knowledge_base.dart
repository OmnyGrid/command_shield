import 'capability.dart';

/// A data-driven knowledge base mapping commands (and their sub-commands and
/// arguments) to the [CommandCapability]s they exercise.
///
/// The base is intentionally heuristic and conservative: when in doubt it
/// errs toward reporting a capability rather than omitting it. It is also
/// extensible — construct one with extra [executableCapabilities] entries to
/// teach it about new tools.
final class CommandKnowledgeBase {
  /// Creates a knowledge base, optionally extending the built-in tables with
  /// [extraExecutableCapabilities].
  CommandKnowledgeBase({
    Map<String, Set<CommandCapability>>? extraExecutableCapabilities,
  }) : executableCapabilities = <String, Set<CommandCapability>>{
         ..._builtinExecutables,
         ...?extraExecutableCapabilities,
       };

  /// The (lower-cased) executable → capabilities table consulted by
  /// [capabilitiesFor].
  final Map<String, Set<CommandCapability>> executableCapabilities;

  /// Commands that wrap and then execute another command supplied in their
  /// arguments (e.g. `sudo rm -rf /`). For these, the wrapped command's
  /// capabilities are also attributed to the invocation.
  static const Set<String> wrapperCommands = <String>{
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
    'builtin',
    'stdbuf',
  };

  /// Returns the set of capabilities for an invocation of [executable] (already
  /// normalized) with [arguments].
  Set<CommandCapability> capabilitiesFor(
    String executable,
    List<String> arguments,
  ) {
    final result = <CommandCapability>{};
    _collect(executable.toLowerCase(), arguments, result, depth: 0);
    return result;
  }

  void _collect(
    String exe,
    List<String> args,
    Set<CommandCapability> out, {
    required int depth,
  }) {
    final base = executableCapabilities[exe];
    if (base != null) out.addAll(base);

    _refine(exe, args, out);

    // Any environment-variable token implies environment access.
    if (args.any(_looksLikeEnvReference)) {
      out.add(CommandCapability.environmentAccess);
    }

    // Recurse into wrapped commands (sudo/env/xargs/...), bounded to avoid
    // pathological inputs.
    if (depth < 4 && wrapperCommands.contains(exe)) {
      final wrapped = _wrappedCommand(exe, args);
      if (wrapped != null) {
        _collect(wrapped.executable, wrapped.arguments, out, depth: depth + 1);
      }
    }
  }

  _Wrapped? _wrappedCommand(String wrapper, List<String> args) {
    // Skip leading option flags and (for env) NAME=VALUE assignments.
    var i = 0;
    while (i < args.length) {
      final a = args[i];
      if (a.startsWith('-')) {
        i++;
        continue;
      }
      if (wrapper == 'env' && a.contains('=')) {
        i++;
        continue;
      }
      break;
    }
    if (i >= args.length) return null;
    final exe = args[i].toLowerCase();
    return _Wrapped(exe, args.sublist(i + 1));
  }

  void _refine(String exe, List<String> args, Set<CommandCapability> out) {
    final sub = args.isNotEmpty ? args.first.toLowerCase() : '';
    switch (exe) {
      case 'git':
        if (const {'push'}.contains(sub)) {
          out.add(CommandCapability.networkWrite);
        } else if (const {'pull', 'clone', 'fetch', 'remote'}.contains(sub)) {
          out.add(CommandCapability.networkRead);
        } else if (const {
          'commit',
          'add',
          'init',
          'checkout',
          'merge',
          'reset',
          'rebase',
          'stash',
          'tag',
          'apply',
          'rm',
          'mv',
          'restore',
        }.contains(sub)) {
          out.add(CommandCapability.writeFilesystem);
        } else {
          out.add(CommandCapability.readFilesystem);
        }
      case 'docker':
      case 'podman':
        if (sub == 'push') {
          out.add(CommandCapability.networkWrite);
        } else if (const {'pull', 'run', 'build', 'login'}.contains(sub)) {
          out
            ..add(CommandCapability.networkRead)
            ..add(CommandCapability.executePrograms);
        }
      case 'npm':
      case 'pnpm':
      case 'yarn':
        if (const {
          'install',
          'i',
          'add',
          'ci',
          'update',
          'audit',
        }.contains(sub)) {
          out
            ..add(CommandCapability.networkRead)
            ..add(CommandCapability.writeFilesystem);
        }
        if (const {'publish'}.contains(sub)) {
          out.add(CommandCapability.networkWrite);
        }
      case 'pip':
      case 'pip3':
        if (const {'install', 'download', 'wheel'}.contains(sub)) {
          out
            ..add(CommandCapability.networkRead)
            ..add(CommandCapability.writeFilesystem);
        }
      case 'apt':
      case 'apt-get':
      case 'brew':
      case 'dnf':
      case 'yum':
      case 'pacman':
        if (const {
          'install',
          'update',
          'upgrade',
          'add',
          'fetch',
          '-s',
        }.contains(sub)) {
          out
            ..add(CommandCapability.networkRead)
            ..add(CommandCapability.writeFilesystem)
            ..add(CommandCapability.systemConfiguration);
        }
      case 'curl':
      case 'wget':
        if (_hasUploadFlag(args)) {
          out.add(CommandCapability.networkWrite);
        }
      case 'ssh':
        // `ssh host cmd` runs a remote program.
        if (args.where((a) => !a.startsWith('-')).length > 1) {
          out.add(CommandCapability.executePrograms);
        }
      case 'sed':
        if (args.any((a) => a == '-i' || a.startsWith('-i'))) {
          out.add(CommandCapability.writeFilesystem);
        }
      case 'find':
        if (args.contains('-delete')) {
          out.add(CommandCapability.deleteFilesystem);
        }
        if (args.contains('-exec') || args.contains('-execdir')) {
          out.add(CommandCapability.executePrograms);
        }
    }
  }

  static bool _hasUploadFlag(List<String> args) => args.any(
    (a) =>
        a == '-d' ||
        a == '--data' ||
        a == '-F' ||
        a == '--form' ||
        a == '-T' ||
        a == '--upload-file' ||
        a == '--data-binary' ||
        (a == '-X' || a == '--request'),
  );

  static bool _looksLikeEnvReference(String token) =>
      token.contains(RegExp(r'\$[A-Za-z_]')) ||
      token.contains(RegExp(r'\$\{[A-Za-z_]')) ||
      token.contains(RegExp(r'\$env:')) ||
      token.contains(RegExp(r'%[A-Za-z_][A-Za-z0-9_]*%'));

  static final Map<String, Set<CommandCapability>>
  _builtinExecutables = <String, Set<CommandCapability>>{
    // --- read-only ---
    for (final c in const [
      'ls',
      'cat',
      'head',
      'tail',
      'grep',
      'egrep',
      'fgrep',
      'pwd',
      'echo',
      'stat',
      'file',
      'wc',
      'less',
      'more',
      'which',
      'whereis',
      'whoami',
      'hostname',
      'date',
      'tree',
      'dir',
      'type',
      'sort',
      'uniq',
      'diff',
      'cmp',
      'dirname',
      'basename',
      'realpath',
      'readlink',
      'getconf',
      'id',
      'uname',
      'df',
      'du',
      'lsblk',
      'get-childitem',
      'get-content',
      'gci',
      'cut',
      'awk',
      'column',
      'fold',
      'nl',
      'tac',
      'strings',
      'md5sum',
      'sha256sum',
      'sha1sum',
      'cksum',
    ])
      c: {CommandCapability.readFilesystem},

    // --- write ---
    for (final c in const [
      'touch',
      'mkdir',
      'cp',
      'copy',
      'tee',
      'truncate',
      'ln',
      'install',
      'patch',
      'xcopy',
      'robocopy',
      'set-content',
      'add-content',
    ])
      c: {CommandCapability.writeFilesystem},
    'dd': {CommandCapability.writeFilesystem, CommandCapability.readFilesystem},
    'mv': {
      CommandCapability.writeFilesystem,
      CommandCapability.deleteFilesystem,
    },
    'move': {
      CommandCapability.writeFilesystem,
      CommandCapability.deleteFilesystem,
    },

    // --- delete ---
    for (final c in const [
      'rm',
      'rmdir',
      'del',
      'erase',
      'unlink',
      'shred',
      'remove-item',
      'ri',
    ])
      c: {CommandCapability.deleteFilesystem},

    // --- execute ---
    for (final c in const [
      'bash',
      'sh',
      'zsh',
      'dash',
      'ksh',
      'fish',
      'csh',
      'tcsh',
      'python',
      'node',
      'ruby',
      'perl',
      'php',
      'java',
      'dart',
      'go',
      'cargo',
      'npx',
      'make',
      'gcc',
      'clang',
      'cc',
      'eval',
      'source',
      'cmd',
      'powershell',
      'deno',
      'flutter',
      'dotnet',
      'mvn',
      'gradle',
      'rake',
      'lua',
      'osascript',
      'rscript',
      'swift',
      'kotlin',
      'scala',
      'invoke-expression',
      'iex',
    ])
      c: {CommandCapability.executePrograms},

    // --- network read ---
    for (final c in const [
      'curl',
      'wget',
      'ftp',
      'sftp',
      'telnet',
      'ping',
      'dig',
      'nslookup',
      'host',
      'whois',
      'traceroute',
      'aria2c',
      'invoke-webrequest',
      'iwr',
      'invoke-restmethod',
      'irm',
    ])
      c: {CommandCapability.networkRead},
    'scp': {
      CommandCapability.networkRead,
      CommandCapability.networkWrite,
      CommandCapability.readFilesystem,
    },
    'rsync': {
      CommandCapability.networkRead,
      CommandCapability.networkWrite,
      CommandCapability.readFilesystem,
    },
    'nc': {CommandCapability.networkRead, CommandCapability.networkWrite},
    'ncat': {CommandCapability.networkRead, CommandCapability.networkWrite},
    'ssh': {CommandCapability.networkRead, CommandCapability.networkWrite},

    // --- privilege escalation ---
    for (final c in const ['sudo', 'su', 'doas', 'pkexec', 'runas'])
      c: {CommandCapability.privilegeEscalation},

    // --- system configuration ---
    for (final c in const [
      'chmod',
      'chown',
      'chgrp',
      'chattr',
      'mount',
      'umount',
      'useradd',
      'userdel',
      'usermod',
      'groupadd',
      'passwd',
      'systemctl',
      'service',
      'launchctl',
      'setfacl',
      'sysctl',
      'reg',
      'netsh',
      'defaults',
      'crontab',
      'iptables',
      'ufw',
      'firewall-cmd',
      'set-itemproperty',
      'new-service',
      'set-acl',
      'setx',
    ])
      c: {CommandCapability.systemConfiguration},

    // --- process management ---
    for (final c in const [
      'kill',
      'killall',
      'pkill',
      'ps',
      'top',
      'htop',
      'nice',
      'renice',
      'taskkill',
      'tasklist',
      'get-process',
      'stop-process',
      'pgrep',
    ])
      c: {CommandCapability.processManagement},

    // --- environment access ---
    for (final c in const ['env', 'printenv', 'export', 'set', 'setenv'])
      c: {CommandCapability.environmentAccess},
  };
}

class _Wrapped {
  _Wrapped(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}
