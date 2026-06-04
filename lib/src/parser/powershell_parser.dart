import '../ast/command_node.dart';
import '../syntax.dart';
import 'command_parser.dart';
import 'parse_diagnostic.dart';
import 'parse_result.dart';

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
    final ast = _PsTokenParser(tokens, diagnostics).parse();
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

  RedirectionType get redirectionType => type == _PsTokenType.redirAppend
      ? RedirectionType.appendOutput
      : RedirectionType.output;
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
          if (_peek(1) == '>') {
            tokens.add(_PsToken(_PsTokenType.redirAppend, '>>', _pos));
            _pos += 2;
          } else {
            tokens.add(_PsToken(_PsTokenType.redirOut, '>', _pos));
            _pos++;
          }
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
    final node = _PsTokenParser(tokens, innerDiag).parse();
    subs.add(
      CommandSubstitution(node ?? const CommandInvocation(executable: '')),
    );
  }
}

class _PsTokenParser {
  _PsTokenParser(this.tokens, this.diagnostics);

  final List<_PsToken> tokens;
  final List<ParseDiagnostic> diagnostics;
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
    return CommandInvocation(
      executable: words.first.value,
      arguments: words.skip(1).map((t) => t.value).toList(growable: false),
      redirections: redirections,
      substitutions: subs,
      environmentReferences: envs,
    );
  }
}
