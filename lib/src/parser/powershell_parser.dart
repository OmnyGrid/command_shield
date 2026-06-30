import '../ast/command_node.dart';
import '../syntax.dart';
import 'command_parser.dart';
import 'inline_exec.dart';
import 'parse_diagnostic.dart';
import 'parse_result.dart';

/// The maximum interpreter-nesting depth re-parsed for inline `-Command` args.
const int _maxInlineDepth = 5;

/// Parser for Microsoft PowerShell.
///
/// Recognises pipelines (`|`), statement separators (`;`), the `&&`/`||`
/// pipeline-chain operators (PowerShell 7+), redirections (`>`, `>>`),
/// command substitution (`$(...)`) and environment-variable references in both
/// `$env:NAME` and `$NAME` forms. Both single and double quotes group text.
final class PowerShellParser extends CommandParser {
  /// Creates a PowerShell parser.
  const PowerShellParser();

  @override
  CommandSyntax get syntax => CommandSyntax.powershell;

  @override
  ParseResult parse(String raw) {
    final diagnostics = <ParseDiagnostic>[];
    final tokens = _PsTokenizer(raw, diagnostics).tokenize();
    final ast = _PsTokenParser(tokens, diagnostics, depth: 0).parse();
    if (ast == null) {
      diagnostics.add(const ParseDiagnostic.info('Empty command'));
    }
    return ParseResult(
      raw: raw,
      syntax: syntax,
      ast: ast,
      diagnostics: diagnostics,
    );
  }
}

enum _PsTokenType {
  word,
  pipe,
  and,
  or,
  semicolon,
  newline,
  redirOut,
  redirAppend,
  redirMerge, // fd duplication: 2>&1, 1>&2, >&1
}

class _PsToken {
  _PsToken(
    this.type,
    this.value,
    this.offset, {
    this.substitutions = const <CommandSubstitution>[],
    this.environmentReferences = const <EnvironmentVariableReference>[],
  });

  final _PsTokenType type;
  final String value;
  final int offset;
  final List<CommandSubstitution> substitutions;
  final List<EnvironmentVariableReference> environmentReferences;

  bool get isRedirection =>
      type == _PsTokenType.redirOut || type == _PsTokenType.redirAppend;

  RedirectionType get redirectionType => switch (type) {
    _PsTokenType.redirAppend => RedirectionType.appendOutput,
    _PsTokenType.redirMerge => RedirectionType.mergeStreams,
    _ => RedirectionType.output,
  };
}

class _PsTokenizer {
  _PsTokenizer(this.input, this.diagnostics);

  final String input;
  final List<ParseDiagnostic> diagnostics;
  int _pos = 0;

  bool get _atEnd => _pos >= input.length;
  String? _peek(int ahead) =>
      _pos + ahead < input.length ? input[_pos + ahead] : null;

  List<_PsToken> tokenize() {
    final tokens = <_PsToken>[];
    while (!_atEnd) {
      final ch = input[_pos];
      if (ch == ' ' || ch == '\t' || ch == '\r') {
        _pos++;
        continue;
      }
      if (ch == '\n') {
        tokens.add(_PsToken(_PsTokenType.newline, '\n', _pos));
        _pos++;
        continue;
      }
      switch (ch) {
        case '|':
          if (_peek(1) == '|') {
            tokens.add(_PsToken(_PsTokenType.or, '||', _pos));
            _pos += 2;
          } else {
            tokens.add(_PsToken(_PsTokenType.pipe, '|', _pos));
            _pos++;
          }
          continue;
        case '&':
          if (_peek(1) == '&') {
            tokens.add(_PsToken(_PsTokenType.and, '&&', _pos));
            _pos += 2;
            continue;
          }
          // A call operator `&` on its own: treat as a separator.
          tokens.add(_PsToken(_PsTokenType.semicolon, '&', _pos));
          _pos++;
          continue;
        case ';':
          tokens.add(_PsToken(_PsTokenType.semicolon, ';', _pos));
          _pos++;
          continue;
        case '>':
          if (_peek(1) == '&') {
            final gtStart = _pos;
            _pos++; // move onto the `&`
            final dup = _tryReadFdDup(gtStart, '>');
            if (dup != null) {
              tokens.add(dup);
            } else {
              _pos++; // consume `&`; the filename follows as a word target.
              tokens.add(_PsToken(_PsTokenType.redirOut, '>&', gtStart));
            }
          } else if (_peek(1) == '>') {
            tokens.add(_PsToken(_PsTokenType.redirAppend, '>>', _pos));
            _pos += 2;
          } else {
            tokens.add(_PsToken(_PsTokenType.redirOut, '>', _pos));
            _pos++;
          }
          continue;
        case '0':
        case '1':
        case '2':
          // A leading single-digit fd is a redirection only when immediately
          // followed by `>` (e.g. `2>&1`); otherwise it is a normal word.
          if (_peek(1) == '>') {
            tokens.add(_readFdRedirect());
            continue;
          }
          tokens.add(_scanWord());
          continue;
        default:
          tokens.add(_scanWord());
      }
    }
    return tokens;
  }

  static bool _isTerminator(String ch) =>
      ch == ' ' ||
      ch == '\t' ||
      ch == '\r' ||
      ch == '\n' ||
      ch == '|' ||
      ch == '&' ||
      ch == ';' ||
      ch == '>';

  static final RegExp _nameStart = RegExp(r'[A-Za-z_]');
  static final RegExp _nameChar = RegExp(r'[A-Za-z0-9_]');

  static bool _isDigit(String? ch) =>
      ch != null && ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;

  static bool _isFdBoundary(String? ch) => ch == null || _isTerminator(ch);

  /// Parses a redirection that begins with an explicit fd digit, with `_pos`
  /// on the digit and `_peek(1) == '>'`. Handles fd duplication (`2>&1`),
  /// append (`2>>`) and plain (`2>`) forms. The non-merge forms collapse to
  /// output redirection.
  _PsToken _readFdRedirect() {
    final start = _pos;
    final fd = input[_pos];
    if (_peek(2) == '&') {
      _pos += 2; // move onto the `&`
      final dup = _tryReadFdDup(start, '$fd>');
      if (dup != null) return dup;
      _pos++; // consume `&`; the filename follows as a word target.
      return _PsToken(_PsTokenType.redirOut, '$fd>&', start);
    }
    if (_peek(2) == '>') {
      _pos += 3;
      return _PsToken(_PsTokenType.redirAppend, '$fd>>', start);
    }
    _pos += 2;
    return _PsToken(_PsTokenType.redirOut, '$fd>', start);
  }

  /// With `_pos` on the `&` of a `…>&…` redirection, returns a
  /// [_PsTokenType.redirMerge] token when a valid fd reference (digits or `-`)
  /// terminated by a word boundary follows, consuming it. Returns `null`
  /// otherwise, leaving `_pos` on the `&`.
  _PsToken? _tryReadFdDup(int start, String prefix) {
    final after = _peek(1);
    if (after == '-') {
      if (_isFdBoundary(_peek(2))) {
        _pos += 2; // consume `&-`
        return _PsToken(_PsTokenType.redirMerge, '$prefix&-', start);
      }
      return null;
    }
    if (!_isDigit(after)) return null;
    var ahead = 1;
    final digits = StringBuffer();
    while (_isDigit(_peek(ahead))) {
      digits.write(_peek(ahead));
      ahead++;
    }
    if (!_isFdBoundary(_peek(ahead))) return null;
    _pos += ahead; // consume `&` plus the fd digits
    return _PsToken(_PsTokenType.redirMerge, '$prefix&$digits', start);
  }

  _PsToken _scanWord() {
    final start = _pos;
    final buffer = StringBuffer();
    final subs = <CommandSubstitution>[];
    final envs = <EnvironmentVariableReference>[];
    while (!_atEnd) {
      final ch = input[_pos];
      if (_isTerminator(ch)) break;
      if (ch == "'") {
        final close = input.indexOf("'", _pos + 1);
        if (close < 0) {
          buffer.write(input.substring(_pos + 1));
          diagnostics.add(
            ParseDiagnostic.warning('Unterminated quote', offset: start),
          );
          _pos = input.length;
          break;
        }
        buffer.write(input.substring(_pos + 1, close));
        _pos = close + 1;
        continue;
      }
      if (ch == '"') {
        _scanDoubleQuote(buffer, subs, envs, start);
        continue;
      }
      if (ch == '`') {
        // PowerShell escape character.
        if (_pos + 1 < input.length) {
          buffer.write(input[_pos + 1]);
          _pos += 2;
        } else {
          _pos++;
        }
        continue;
      }
      if (ch == r'$') {
        _scanDollar(buffer, subs, envs);
        continue;
      }
      buffer.write(ch);
      _pos++;
    }
    return _PsToken(
      _PsTokenType.word,
      buffer.toString(),
      start,
      substitutions: subs,
      environmentReferences: envs,
    );
  }

  void _scanDoubleQuote(
    StringBuffer buffer,
    List<CommandSubstitution> subs,
    List<EnvironmentVariableReference> envs,
    int start,
  ) {
    _pos++; // opening quote
    while (!_atEnd) {
      final c = input[_pos];
      if (c == '"') {
        _pos++;
        return;
      }
      if (c == '`' && _pos + 1 < input.length) {
        buffer.write(input[_pos + 1]);
        _pos += 2;
        continue;
      }
      if (c == r'$') {
        _scanDollar(buffer, subs, envs);
        continue;
      }
      buffer.write(c);
      _pos++;
    }
    diagnostics.add(
      ParseDiagnostic.warning('Unterminated quote', offset: start),
    );
  }

  void _scanDollar(
    StringBuffer buffer,
    List<CommandSubstitution> subs,
    List<EnvironmentVariableReference> envs,
  ) {
    final next = _peek(1);
    if (next == '(') {
      _scanSubstitution(buffer, subs);
      return;
    }
    // $env:NAME
    if (input.startsWith(r'$env:', _pos)) {
      var end = _pos + 5;
      while (end < input.length && _nameChar.hasMatch(input[end])) {
        end++;
      }
      final name = input.substring(_pos + 5, end);
      if (name.isNotEmpty) {
        envs.add(EnvironmentVariableReference(name));
      }
      buffer.write(input.substring(_pos, end));
      _pos = end;
      return;
    }
    if (next != null && _nameStart.hasMatch(next)) {
      var end = _pos + 1;
      while (end < input.length && _nameChar.hasMatch(input[end])) {
        end++;
      }
      final name = input.substring(_pos + 1, end);
      envs.add(EnvironmentVariableReference(name));
      buffer.write(input.substring(_pos, end));
      _pos = end;
      return;
    }
    buffer.write(r'$');
    _pos++;
  }

  void _scanSubstitution(StringBuffer buffer, List<CommandSubstitution> subs) {
    final start = _pos;
    var depth = 0;
    var i = _pos + 1;
    for (; i < input.length; i++) {
      final c = input[i];
      if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    if (depth != 0) {
      diagnostics.add(
        ParseDiagnostic.warning('Unterminated subexpression', offset: start),
      );
      _addSub(input.substring(_pos + 2), subs);
      buffer.write(input.substring(_pos));
      _pos = input.length;
      return;
    }
    _addSub(input.substring(_pos + 2, i), subs);
    buffer.write(input.substring(_pos, i + 1));
    _pos = i + 1;
  }

  void _addSub(String inner, List<CommandSubstitution> subs) {
    final innerDiag = <ParseDiagnostic>[];
    final tokens = _PsTokenizer(inner, innerDiag).tokenize();
    final node = _PsTokenParser(tokens, innerDiag, depth: 0).parse();
    subs.add(
      CommandSubstitution(node ?? const CommandInvocation(executable: '')),
    );
  }
}

class _PsTokenParser {
  _PsTokenParser(this.tokens, this.diagnostics, {required this.depth});

  final List<_PsToken> tokens;
  final List<ParseDiagnostic> diagnostics;

  /// How many interpreter `-Command` boundaries deep this parser is nested.
  final int depth;
  int _i = 0;

  bool get _atEnd => _i >= tokens.length;

  CommandNode? parse() {
    final lines = <CommandNode>[];
    while (!_atEnd) {
      while (!_atEnd && tokens[_i].type == _PsTokenType.newline) {
        _i++;
      }
      if (_atEnd) break;
      final before = _i;
      final chain = _parseChain();
      if (chain != null) lines.add(chain);
      if (!_atEnd && tokens[_i].type == _PsTokenType.newline) {
        _i++;
      } else if (_i == before) {
        // Guarantee forward progress on malformed input that begins with an
        // operator, otherwise the loop would never terminate.
        diagnostics.add(
          ParseDiagnostic.warning(
            'Unexpected token "${tokens[_i].value}"',
            offset: tokens[_i].offset,
          ),
        );
        _i++;
      }
    }
    if (lines.isEmpty) return null;
    if (lines.length == 1) return lines.first;
    return CommandScript(lines);
  }

  CommandNode? _parseChain() {
    var left = _parsePipeline();
    if (left == null) return null;
    while (!_atEnd) {
      final op = switch (tokens[_i].type) {
        _PsTokenType.semicolon => ChainOperator.sequential,
        _PsTokenType.and => ChainOperator.and,
        _PsTokenType.or => ChainOperator.or,
        _ => null,
      };
      if (op == null) break;
      _i++;
      final right = _parsePipeline();
      if (right == null) break;
      if (left is CommandChain && left.operator == op) {
        left = CommandChain(
          commands: <CommandNode>[...left.commands, right],
          operator: op,
        );
      } else {
        left = CommandChain(
          commands: <CommandNode>[left!, right],
          operator: op,
        );
      }
    }
    return left;
  }

  CommandNode? _parsePipeline() {
    final first = _parseCommand();
    if (first == null) return null;
    final commands = <CommandNode>[first];
    while (!_atEnd && tokens[_i].type == _PsTokenType.pipe) {
      _i++;
      final next = _parseCommand();
      if (next == null) break;
      commands.add(next);
    }
    if (commands.length == 1) return commands.first;
    return Pipeline(commands);
  }

  CommandNode? _parseCommand() {
    final words = <_PsToken>[];
    final redirections = <RedirectionNode>[];
    final subs = <CommandSubstitution>[];
    final envs = <EnvironmentVariableReference>[];
    while (!_atEnd) {
      final tok = tokens[_i];
      if (tok.type == _PsTokenType.word) {
        words.add(tok);
        subs.addAll(tok.substitutions);
        envs.addAll(tok.environmentReferences);
        _i++;
        continue;
      }
      if (tok.type == _PsTokenType.redirMerge) {
        // Fd duplication (`2>&1`) carries its own target and consumes no word.
        redirections.add(
          RedirectionNode(
            type: RedirectionType.mergeStreams,
            target: tok.value,
          ),
        );
        _i++;
        continue;
      }
      if (tok.isRedirection) {
        _i++;
        if (!_atEnd && tokens[_i].type == _PsTokenType.word) {
          redirections.add(
            RedirectionNode(
              type: tok.redirectionType,
              target: tokens[_i].value,
            ),
          );
          _i++;
        } else {
          redirections.add(
            RedirectionNode(type: tok.redirectionType, target: ''),
          );
        }
        continue;
      }
      break;
    }
    if (words.isEmpty) return null;
    final executable = words.first.value;
    final arguments = words.skip(1).map((t) => t.value).toList(growable: false);
    return CommandInvocation(
      executable: executable,
      arguments: arguments,
      redirections: redirections,
      substitutions: subs,
      environmentReferences: envs,
      inlineCommand: _parseInlineCommand(executable, arguments),
    );
  }

  /// Re-parses the inline command string of `powershell -Command "..."` into a
  /// nested AST. `-EncodedCommand` is excluded by [inlineScriptArgIndex].
  CommandNode? _parseInlineCommand(String executable, List<String> arguments) {
    if (depth >= _maxInlineDepth) return null;
    final index = inlineScriptArgIndex(executable, arguments);
    if (index == null) return null;
    final script = arguments[index];
    if (script.isEmpty) return null;
    final innerDiag = <ParseDiagnostic>[];
    final innerTokens = _PsTokenizer(script, innerDiag).tokenize();
    return _PsTokenParser(innerTokens, innerDiag, depth: depth + 1).parse();
  }
}
