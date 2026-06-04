import '../ast/command_node.dart';
import '../normalization/normalizer.dart';
import '../syntax.dart';
import 'security_finding.dart';

/// Immutable input shared by all [SecurityDetector]s.
final class SecurityContext {
  /// Creates a security context.
  SecurityContext({
    required this.raw,
    required this.syntax,
    required this.ast,
    required this.normalizer,
  });

  /// The original command string.
  final String raw;

  /// The syntax the command was parsed with.
  final CommandSyntax syntax;

  /// The parsed AST, or `null` if nothing could be parsed.
  final CommandNode? ast;

  /// The normalizer used to canonicalise executables.
  final Normalizer normalizer;

  /// All command invocations in [ast], depth-first.
  late final List<CommandInvocation> invocations =
      ast?.walk().whereType<CommandInvocation>().toList(growable: false) ??
      const <CommandInvocation>[];

  /// All pipelines in [ast], depth-first.
  late final List<Pipeline> pipelines =
      ast?.walk().whereType<Pipeline>().toList(growable: false) ??
      const <Pipeline>[];

  /// The normalized executable name for [invocation].
  String normalizedExecutable(CommandInvocation invocation) =>
      normalizer.normalize(invocation.executable);

  /// The `raw` string with single- and double-quoted spans blanked out (spaces
  /// substituted) so detectors can scan for operators without matching quoted
  /// literals. Length and offsets are preserved.
  late final String unquotedRaw = _blankQuotes(raw, blankDouble: true);

  /// Like [unquotedRaw] but only single-quoted spans are blanked, since shell
  /// expansion (`$(...)`, `$VAR`) remains active inside double quotes.
  late final String singleUnquotedRaw = _blankQuotes(raw, blankDouble: false);

  static String _blankQuotes(String input, {required bool blankDouble}) {
    final out = StringBuffer();
    var i = 0;
    final n = input.length;
    while (i < n) {
      final ch = input[i];
      if (ch == r'\') {
        out.write(' ');
        if (i + 1 < n) {
          out.write(' ');
          i += 2;
        } else {
          i++;
        }
        continue;
      }
      if (ch == "'" || (ch == '"' && blankDouble)) {
        final close = input.indexOf(ch, i + 1);
        if (close < 0) {
          // Unterminated: blank to end.
          for (var j = i; j < n; j++) {
            out.write(' ');
          }
          i = n;
        } else {
          for (var j = i; j <= close; j++) {
            out.write(' ');
          }
          i = close + 1;
        }
        continue;
      }
      out.write(ch);
      i++;
    }
    return out.toString();
  }
}

/// A single security detector. Implementations are pure and deterministic and
/// must never execute anything.
abstract class SecurityDetector {
  /// Const base constructor for subclasses.
  const SecurityDetector();

  /// A stable identifier for the detector (matches the [SecurityFinding.code]
  /// it emits).
  String get code;

  /// Returns any findings for [context]. Returns an empty list when nothing is
  /// detected.
  List<SecurityFinding> detect(SecurityContext context);
}

/// Shared helpers for recognising command families inside detectors.
abstract final class CommandFamilies {
  /// Shells and interpreters that execute arbitrary code passed to them.
  static const Set<String> shells = <String>{
    'bash',
    'sh',
    'zsh',
    'dash',
    'ksh',
    'fish',
    'csh',
    'tcsh',
    'cmd',
    'powershell',
    'python',
    'node',
    'ruby',
    'perl',
    'php',
    'deno',
  };

  /// Tools that download content from the network.
  static const Set<String> downloaders = <String>{
    'curl',
    'wget',
    'aria2c',
    'fetch',
    'invoke-webrequest',
    'iwr',
    'invoke-restmethod',
    'irm',
  };

  /// Privilege-escalation commands.
  static const Set<String> privilege = <String>{
    'sudo',
    'su',
    'doas',
    'pkexec',
    'runas',
  };

  /// File/directory deletion commands.
  static const Set<String> destructive = <String>{
    'rm',
    'rmdir',
    'del',
    'erase',
    'unlink',
    'shred',
    'remove-item',
    'ri',
  };
}
