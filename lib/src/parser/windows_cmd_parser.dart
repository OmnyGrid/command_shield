import '../ast/command_node.dart';
import '../syntax.dart';
import 'command_parser.dart';
import 'parse_diagnostic.dart';
import 'parse_result.dart';

/// Parser for the Windows Command Prompt (`cmd.exe`) batch syntax.
///
/// Recognises command separators (`&`, `&&`, `||`), pipelines (`|`),
/// redirections (`>`, `>>`, `<`) and `%VAR%` environment-variable references.
/// In `cmd`, single quotes are not special; only double quotes group text.
final class WindowsCmdParser extends CommandParser {
  /// Creates a Windows CMD parser.
  const WindowsCmdParser();

  @override
  CommandSyntax get syntax => CommandSyntax.windowsCmd;

  @override
  ParseResult parse(String raw) {
    final diagnostics = <ParseDiagnostic>[];
    final tokens = _CmdTokenizer(raw, diagnostics).tokenize();
    final ast = _CmdTokenParser(tokens, diagnostics).parse();
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

enum _CmdTokenType { word, pipe, and, or, amp, redirOut, redirAppend, redirIn }

class _CmdToken {
  _CmdToken(
    this.type,
    this.value,
    this.offset, {
    this.environmentReferences = const <EnvironmentVariableReference>[],
  });

  final _CmdTokenType type;
  final String value;
  final int offset;
  final List<EnvironmentVariableReference> environmentReferences;

  bool get isRedirection =>
      type == _CmdTokenType.redirOut ||
      type == _CmdTokenType.redirAppend ||
      type == _CmdTokenType.redirIn;

  RedirectionType get redirectionType => switch (type) {
    _CmdTokenType.redirAppend => RedirectionType.appendOutput,
    _CmdTokenType.redirIn => RedirectionType.input,
    _ => RedirectionType.output,
  };
}

class _CmdTokenizer {
  _CmdTokenizer(this.input, this.diagnostics);

  final String input;
  final List<ParseDiagnostic> diagnostics;
  int _pos = 0;

  bool get _atEnd => _pos >= input.length;
  String? _peek(int ahead) =>
      _pos + ahead < input.length ? input[_pos + ahead] : null;

  List<_CmdToken> tokenize() {
    final tokens = <_CmdToken>[];
    while (!_atEnd) {
      final ch = input[_pos];
      if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') {
        _pos++;
        continue;
      }
      switch (ch) {
        case '|':
          if (_peek(1) == '|') {
            tokens.add(_CmdToken(_CmdTokenType.or, '||', _pos));
            _pos += 2;
          } else {
            tokens.add(_CmdToken(_CmdTokenType.pipe, '|', _pos));
            _pos++;
          }
          continue;
        case '&':
          if (_peek(1) == '&') {
            tokens.add(_CmdToken(_CmdTokenType.and, '&&', _pos));
            _pos += 2;
          } else {
            tokens.add(_CmdToken(_CmdTokenType.amp, '&', _pos));
            _pos++;
          }
          continue;
        case '>':
          if (_peek(1) == '>') {
            tokens.add(_CmdToken(_CmdTokenType.redirAppend, '>>', _pos));
            _pos += 2;
          } else {
            tokens.add(_CmdToken(_CmdTokenType.redirOut, '>', _pos));
            _pos++;
          }
          continue;
        case '<':
          tokens.add(_CmdToken(_CmdTokenType.redirIn, '<', _pos));
          _pos++;
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
      ch == '>' ||
      ch == '<';

  _CmdToken _scanWord() {
    final start = _pos;
    final buffer = StringBuffer();
    final envs = <EnvironmentVariableReference>[];
    while (!_atEnd) {
      final ch = input[_pos];
      if (_isTerminator(ch)) break;
      if (ch == '"') {
        final close = input.indexOf('"', _pos + 1);
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
      if (ch == '%') {
        final close = input.indexOf('%', _pos + 1);
        if (close > _pos) {
          final name = input.substring(_pos + 1, close);
          if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
            envs.add(EnvironmentVariableReference(name));
            buffer.write(input.substring(_pos, close + 1));
            _pos = close + 1;
            continue;
          }
        }
        buffer.write(ch);
        _pos++;
        continue;
      }
      buffer.write(ch);
      _pos++;
    }
    return _CmdToken(
      _CmdTokenType.word,
      buffer.toString(),
      start,
      environmentReferences: envs,
    );
  }
}

class _CmdTokenParser {
  _CmdTokenParser(this.tokens, this.diagnostics);

  final List<_CmdToken> tokens;
  final List<ParseDiagnostic> diagnostics;
  int _i = 0;

  bool get _atEnd => _i >= tokens.length;

  CommandNode? parse() {
    var left = _parsePipeline();
    if (left == null) return null;
    while (!_atEnd) {
      final op = switch (tokens[_i].type) {
        _CmdTokenType.amp => ChainOperator.sequential,
        _CmdTokenType.and => ChainOperator.and,
        _CmdTokenType.or => ChainOperator.or,
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
    while (!_atEnd && tokens[_i].type == _CmdTokenType.pipe) {
      _i++;
      final next = _parseCommand();
      if (next == null) break;
      commands.add(next);
    }
    if (commands.length == 1) return commands.first;
    return Pipeline(commands);
  }

  CommandNode? _parseCommand() {
    final words = <_CmdToken>[];
    final redirections = <RedirectionNode>[];
    final envs = <EnvironmentVariableReference>[];
    while (!_atEnd) {
      final tok = tokens[_i];
      if (tok.type == _CmdTokenType.word) {
        words.add(tok);
        envs.addAll(tok.environmentReferences);
        _i++;
        continue;
      }
      if (tok.isRedirection) {
        _i++;
        if (!_atEnd && tokens[_i].type == _CmdTokenType.word) {
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
          diagnostics.add(
            ParseDiagnostic.warning(
              'Redirection without a target',
              offset: tok.offset,
            ),
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
      environmentReferences: envs,
    );
  }
}
