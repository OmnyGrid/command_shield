/// Recognises interpreter invocations that run a command string supplied
/// inline as an argument — `bash -c "..."`, `sh -c '...'`, `cmd /c ...`,
/// `powershell -Command "..."` — so parsers can re-parse that string into a
/// nested AST and have it analyzed like any other command.
///
/// Shared by the shell, Windows CMD and PowerShell parsers to keep the
/// flag-recognition rules in one place.
library;

/// POSIX-family shells that take a script via `-c`/`--command`.
const Set<String> _posixShells = <String>{
  'sh',
  'bash',
  'zsh',
  'dash',
  'ksh',
  'fish',
  'csh',
  'tcsh',
};

/// PowerShell-family interpreters that take a script via `-Command`.
const Set<String> _powerShells = <String>{'powershell', 'pwsh'};

/// PowerShell encoded-command flag forms, which carry base64 (not parseable
/// source) and so are deliberately left un-recursed.
const Set<String> _encodedForms = <String>{
  '-e',
  '-ec',
  '-enc',
  '-encodedcommand',
};

/// The lowercase base name of [executable], with any directory prefix and a
/// trailing `.exe` removed (e.g. `/usr/bin/bash` and `BASH.EXE` → `bash`).
String inlineExecBasename(String executable) {
  var name = executable;
  final slash = name.lastIndexOf(RegExp(r'[\\/]'));
  if (slash >= 0) name = name.substring(slash + 1);
  name = name.toLowerCase();
  if (name.endsWith('.exe')) name = name.substring(0, name.length - 4);
  return name;
}

/// Returns the index into [arguments] of the argument holding the inline
/// command string for an [executable] invocation, or `null` when this is not
/// an inline-execution invocation (so nothing should be re-parsed).
///
/// Recognises POSIX `-c`/`--command` (including bundled short flags ending in
/// `c`, e.g. `-ec`), Windows `cmd /c`/`/k`, and PowerShell `-Command`. The
/// PowerShell `-EncodedCommand` family is intentionally excluded.
int? inlineScriptArgIndex(String executable, List<String> arguments) {
  final exe = inlineExecBasename(executable);

  if (_posixShells.contains(exe)) {
    return _argAfter(arguments, _isPosixCommandFlag);
  }
  if (exe == 'cmd') {
    return _argAfter(arguments, (a) {
      final l = a.toLowerCase();
      return l == '/c' || l == '/k';
    });
  }
  if (_powerShells.contains(exe)) {
    return _argAfter(arguments, (a) {
      final l = a.toLowerCase();
      if (_encodedForms.contains(l) || l.startsWith('-encoded')) return false;
      // Mirrors ShellExecutionDetector: `-Command` and its `-c…` abbreviations.
      return l == '-command' || l.startsWith('-c');
    });
  }
  return null;
}

/// `-c`, `--command`, or a bundled short-option group ending in `c`
/// (`-ec`, `-xc`, ...) — but not long options like `--config`.
bool _isPosixCommandFlag(String a) {
  if (a == '-c' || a == '--command') return true;
  if (a.length >= 2 &&
      a[0] == '-' &&
      a[1] != '-' &&
      a.endsWith('c') &&
      RegExp(r'^-[a-z]+$').hasMatch(a)) {
    return true;
  }
  return false;
}

/// The index immediately following the first argument matching [isFlag], when
/// such an argument exists and is followed by another argument.
int? _argAfter(List<String> arguments, bool Function(String) isFlag) {
  for (var i = 0; i < arguments.length; i++) {
    if (isFlag(arguments[i])) {
      final next = i + 1;
      return next < arguments.length ? next : null;
    }
  }
  return null;
}
