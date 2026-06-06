import '../ast/command_node.dart';
import '../syntax.dart';
import 'command_parser.dart';
import 'inline_exec.dart';
import 'parse_diagnostic.dart';
import 'parse_result.dart';

/// The maximum interpreter-nesting depth re-parsed for inline `-c` arguments,
/// guarding against pathological inputs like `bash -c "bash -c \"...\""`.
const int _maxInlineDepth = 5;

/// Shared implementation for POSIX/Bash-family shells.
///
/// Recognises pipelines (`|`), command chaining (`;`, `&&`, `||`), I/O
/// redirection (`>`, `>>`, `<`, `<<`, `2>`, `2>>`), command substitution
/// (`$(...)` and back-ticks), environment-variable references (`$VAR`,
/// `${VAR}`) and multi-line scripts. It never executes anything and never
/// throws — problems are reported as [ParseDiagnostic]s.
///
/// Concrete subclasses ([BashParser], [PosixParser]) only differ in the
/// [syntax] they report.
abstract base class ShellParser extends CommandParser {
  /// Const base constructor for subclasses.
  const ShellParser();

  @override
  ParseResult parse(String raw) {
    final diagnostics = <ParseDiagnostic>[];
    final tokenizer = _ShellTokenizer(raw, diagnostics);
    final tokens = tokenizer.tokenize();
    final parser = _TokenParser(tokens, diagnostics, depth: 0);
    final ast = parser.parseScript();
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

/// The GNU Bourne-Again Shell parser.
final class BashParser extends ShellParser {
  /// Creates a bash parser.
  const BashParser();

  @override
  CommandSyntax get syntax => CommandSyntax.bash;
}

/// The POSIX shell parser (the portable subset shared with bash).
final class PosixParser extends ShellParser {
  /// Creates a POSIX shell parser.
  const PosixParser();

  @override
  CommandSyntax get syntax => CommandSyntax.posixShell;
}

// --- Tokens ---------------------------------------------------------------

enum _TokenType {
  word,
  pipe, // |
  and, // &&
  or, // ||
  semicolon, // ;
  newline, // \n
  redirOut, // >
  redirAppend, // >>
  redirIn, // <
  redirHereDoc, // <<
  redirErr, // 2>
  redirErrAppend, // 2>>
}

class _Token {
  _Token(
    this.type,
    this.value,
    this.offset, {
    this.substitutions = const <CommandSubstitution>[],
    this.environmentReferences = const <EnvironmentVariableReference>[],
  });

  final _TokenType type;
  final String value;
  final int offset;
  final List<CommandSubstitution> substitutions;
  final List<EnvironmentVariableReference> environmentReferences;

  bool get isRedirection => const {
    _TokenType.redirOut,
    _TokenType.redirAppend,
    _TokenType.redirIn,
    _TokenType.redirHereDoc,
    _TokenType.redirErr,
    _TokenType.redirErrAppend,
  }.contains(type);

  RedirectionType get redirectionType => switch (type) {
    _TokenType.redirOut => RedirectionType.output,
    _TokenType.redirAppend => RedirectionType.appendOutput,
    _TokenType.redirIn => RedirectionType.input,
    _TokenType.redirHereDoc => RedirectionType.hereDocument,
    _TokenType.redirErr => RedirectionType.errorOutput,
    _TokenType.redirErrAppend => RedirectionType.appendErrorOutput,
    _ => RedirectionType.output,
  };
}

// --- Tokenizer ------------------------------------------------------------

class _ShellTokenizer {
  _ShellTokenizer(this.input, this.diagnostics);

  final String input;
  final List<ParseDiagnostic> diagnostics;
  int _pos = 0;

  bool get _atEnd => _pos >= input.length;
  String get _ch => input[_pos];
  String? _peek(int ahead) =>
      _pos + ahead < input.length ? input[_pos + ahead] : null;

  List<_Token> tokenize() {
    final tokens = <_Token>[];
    while (!_atEnd) {
      final ch = _ch;
      if (ch == ' ' || ch == '\t' || ch == '\r') {
        _pos++;
        continue;
      }
      if (ch == '\n') {
        tokens.add(_Token(_TokenType.newline, '\n', _pos));
        _pos++;
        continue;
      }
      final op = _tryOperator();
      if (op != null) {
        tokens.add(op);
        continue;
      }
      tokens.add(_scanWord());
    }
    return tokens;
  }

  _Token? _tryOperator() {
    final start = _pos;
    final ch = _ch;
    switch (ch) {
      case '|':
        if (_peek(1) == '|') {
          _pos += 2;
          return _Token(_TokenType.or, '||', start);
        }
        _pos++;
        return _Token(_TokenType.pipe, '|', start);
      case ';':
        _pos++;
        return _Token(_TokenType.semicolon, ';', start);
      case '&':
        if (_peek(1) == '&') {
          _pos += 2;
          return _Token(_TokenType.and, '&&', start);
        }
        // A lone `&` (background) is treated as a sequential separator.
        _pos++;
        return _Token(_TokenType.semicolon, '&', start);
      case '>':
        if (_peek(1) == '>') {
          _pos += 2;
          return _Token(_TokenType.redirAppend, '>>', start);
        }
        _pos++;
        return _Token(_TokenType.redirOut, '>', start);
      case '<':
        if (_peek(1) == '<') {
          _pos += 2;
          return _Token(_TokenType.redirHereDoc, '<<', start);
        }
        _pos++;
        return _Token(_TokenType.redirIn, '<', start);
      case '2':
        if (_peek(1) == '>') {
          if (_peek(2) == '>') {
            _pos += 3;
            return _Token(_TokenType.redirErrAppend, '2>>', start);
          }
          _pos += 2;
          return _Token(_TokenType.redirErr, '2>', start);
        }
        return null;
      default:
        return null;
    }
  }

  static bool _isWordTerminator(String ch) =>
      ch == ' ' ||
      ch == '\t' ||
      ch == '\r' ||
      ch == '\n' ||
      ch == '|' ||
      ch == '&' ||
      ch == ';' ||
      ch == '<' ||
      ch == '>';

  static bool _isNameStart(String ch) => RegExp(r'[A-Za-z_]').hasMatch(ch);
  static bool _isNameChar(String ch) => RegExp(r'[A-Za-z0-9_]').hasMatch(ch);

  _Token _scanWord() {
    final start = _pos;
    final buffer = StringBuffer();
    final subs = <CommandSubstitution>[];
    final envs = <EnvironmentVariableReference>[];

    while (!_atEnd) {
      final ch = _ch;
      if (_isWordTerminator(ch)) break;
      // `2>` redirection breaks the word only when `2` stands alone; if we are
      // mid-word the `2` is an ordinary character handled below.
      if (ch == "'") {
        _scanSingleQuote(buffer);
        continue;
      }
      if (ch == '"') {
        _scanDoubleQuote(buffer, subs, envs);
        continue;
      }
      if (ch == r'\') {
        if (_pos + 1 < input.length) {
          buffer.write(input[_pos + 1]);
          _pos += 2;
        } else {
          buffer.write(ch);
          _pos++;
        }
        continue;
      }
      if (ch == r'$') {
        _scanDollar(buffer, subs, envs);
        continue;
      }
      if (ch == '`') {
        _scanBacktick(buffer, subs);
        continue;
      }
      buffer.write(ch);
      _pos++;
    }

    return _Token(
      _TokenType.word,
      buffer.toString(),
      start,
      substitutions: subs,
      environmentReferences: envs,
    );
  }

  void _scanSingleQuote(StringBuffer buffer) {
    final start = _pos;
    final close = input.indexOf("'", _pos + 1);
    if (close < 0) {
      buffer.write(input.substring(_pos + 1));
      diagnostics.add(
        ParseDiagnostic.warning('Unterminated single quote', offset: start),
      );
      _pos = input.length;
      return;
    }
    buffer.write(input.substring(_pos + 1, close));
    _pos = close + 1;
  }

  void _scanDoubleQuote(
    StringBuffer buffer,
    List<CommandSubstitution> subs,
    List<EnvironmentVariableReference> envs,
  ) {
    final start = _pos;
    _pos++; // consume opening quote
    while (!_atEnd) {
      final c = _ch;
      if (c == '"') {
        _pos++;
        return;
      }
      if (c == r'\' && _pos + 1 < input.length) {
        final next = input[_pos + 1];
        if (next == '"' || next == r'\' || next == r'$' || next == '`') {
          buffer.write(next);
          _pos += 2;
          continue;
        }
        buffer.write(c);
        _pos++;
        continue;
      }
      if (c == r'$') {
        _scanDollar(buffer, subs, envs);
        continue;
      }
      if (c == '`') {
        _scanBacktick(buffer, subs);
        continue;
      }
      buffer.write(c);
      _pos++;
    }
    diagnostics.add(
      ParseDiagnostic.warning('Unterminated double quote', offset: start),
    );
  }

  void _scanDollar(
    StringBuffer buffer,
    List<CommandSubstitution> subs,
    List<EnvironmentVariableReference> envs,
  ) {
    final next = _peek(1);
    if (next == '(') {
      _scanCommandSubstitution(buffer, subs);
      return;
    }
    if (next == '{') {
      _scanBracedEnv(buffer, envs);
      return;
    }
    if (next != null && _isNameStart(next)) {
      final nameStart = _pos + 1;
      var end = nameStart;
      while (end < input.length && _isNameChar(input[end])) {
        end++;
      }
      final name = input.substring(nameStart, end);
      envs.add(EnvironmentVariableReference(name));
      buffer.write(input.substring(_pos, end));
      _pos = end;
      return;
    }
    // Lone `$` or special parameter ($?, $$, $1, ...): keep literally.
    buffer.write(r'$');
    _pos++;
  }

  void _scanBracedEnv(
    StringBuffer buffer,
    List<EnvironmentVariableReference> envs,
  ) {
    final start = _pos;
    final close = input.indexOf('}', _pos + 2);
    if (close < 0) {
      diagnostics.add(
        ParseDiagnostic.warning(
          'Unterminated \${...} expansion',
          offset: start,
        ),
      );
      buffer.write(input.substring(_pos));
      _pos = input.length;
      return;
    }
    final inner = input.substring(_pos + 2, close);
    // Strip parameter-expansion operators to recover the bare name.
    final name = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*').stringMatch(inner) ?? inner;
    if (name.isNotEmpty) {
      envs.add(EnvironmentVariableReference(name));
    }
    buffer.write(input.substring(_pos, close + 1));
    _pos = close + 1;
  }

  void _scanCommandSubstitution(
    StringBuffer buffer,
    List<CommandSubstitution> subs,
  ) {
    final start = _pos;
    var depth = 0;
    var i = _pos + 1; // points at '('
    for (; i < input.length; i++) {
      final c = input[i];
      if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
        if (depth == 0) {
          break;
        }
      }
    }
    if (depth != 0) {
      diagnostics.add(
        ParseDiagnostic.warning(
          'Unterminated command substitution',
          offset: start,
        ),
      );
      final inner = input.substring(_pos + 2);
      _addSubstitution(inner, subs);
      buffer.write(input.substring(_pos));
      _pos = input.length;
      return;
    }
    final inner = input.substring(_pos + 2, i);
    _addSubstitution(inner, subs);
    buffer.write(input.substring(_pos, i + 1));
    _pos = i + 1;
  }

  void _scanBacktick(StringBuffer buffer, List<CommandSubstitution> subs) {
    final start = _pos;
    final close = input.indexOf('`', _pos + 1);
    if (close < 0) {
      diagnostics.add(
        ParseDiagnostic.warning(
          'Unterminated back-tick substitution',
          offset: start,
        ),
      );
      final inner = input.substring(_pos + 1);
      _addSubstitution(inner, subs);
      buffer.write(input.substring(_pos));
      _pos = input.length;
      return;
    }
    final inner = input.substring(_pos + 1, close);
    _addSubstitution(inner, subs);
    buffer.write(input.substring(_pos, close + 1));
    _pos = close + 1;
  }

  void _addSubstitution(String inner, List<CommandSubstitution> subs) {
    final innerDiagnostics = <ParseDiagnostic>[];
    final tokens = _ShellTokenizer(inner, innerDiagnostics).tokenize();
    final node = _TokenParser(tokens, innerDiagnostics, depth: 0).parseScript();
    subs.add(
      CommandSubstitution(node ?? const CommandInvocation(executable: '')),
    );
  }
}

// --- Recursive-descent parser over tokens --------------------------------

class _TokenParser {
  _TokenParser(this.tokens, this.diagnostics, {required this.depth});

  final List<_Token> tokens;
  final List<ParseDiagnostic> diagnostics;

  /// How many interpreter `-c` boundaries deep this parser is nested.
  final int depth;
  int _i = 0;

  bool get _atEnd => _i >= tokens.length;
  _Token get _current => tokens[_i];

  /// Parses a whole script. Returns `null` if there are no commands at all.
  CommandNode? parseScript() {
    final lines = <CommandNode>[];
    while (!_atEnd) {
      while (!_atEnd && _current.type == _TokenType.newline) {
        _i++;
      }
      if (_atEnd) break;
      final before = _i;
      final chain = _parseChain();
      if (chain != null) {
        lines.add(chain);
      }
      if (!_atEnd && _current.type == _TokenType.newline) {
        _i++;
      } else if (_i == before) {
        // Guarantee forward progress on malformed input that begins with an
        // operator (e.g. `| | |`), otherwise the loop would never terminate.
        diagnostics.add(
          ParseDiagnostic.warning(
            'Unexpected token "${_current.value}"',
            offset: _current.offset,
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
      final type = _current.type;
      final op = switch (type) {
        _TokenType.semicolon => ChainOperator.sequential,
        _TokenType.and => ChainOperator.and,
        _TokenType.or => ChainOperator.or,
        _ => null,
      };
      if (op == null) break;
      _i++;
      final right = _parsePipeline();
      if (right == null) {
        diagnostics.add(
          const ParseDiagnostic.warning('Chain operator with no command'),
        );
        break;
      }
      left = _foldChain(left!, op, right);
    }
    return left;
  }

  CommandNode _foldChain(
    CommandNode left,
    ChainOperator op,
    CommandNode right,
  ) {
    if (left is CommandChain && left.operator == op) {
      return CommandChain(
        commands: <CommandNode>[...left.commands, right],
        operator: op,
      );
    }
    return CommandChain(commands: <CommandNode>[left, right], operator: op);
  }

  CommandNode? _parsePipeline() {
    final first = _parseCommand();
    if (first == null) return null;
    final commands = <CommandNode>[first];
    while (!_atEnd && _current.type == _TokenType.pipe) {
      _i++;
      final next = _parseCommand();
      if (next == null) {
        diagnostics.add(
          const ParseDiagnostic.warning('Pipe with no following command'),
        );
        break;
      }
      commands.add(next);
    }
    if (commands.length == 1) return commands.first;
    return Pipeline(commands);
  }

  CommandNode? _parseCommand() {
    final words = <_Token>[];
    final redirections = <RedirectionNode>[];
    final subs = <CommandSubstitution>[];
    final envs = <EnvironmentVariableReference>[];

    while (!_atEnd) {
      final tok = _current;
      if (tok.type == _TokenType.word) {
        words.add(tok);
        subs.addAll(tok.substitutions);
        envs.addAll(tok.environmentReferences);
        _i++;
        continue;
      }
      if (tok.isRedirection) {
        _i++;
        if (!_atEnd && _current.type == _TokenType.word) {
          redirections.add(
            RedirectionNode(type: tok.redirectionType, target: _current.value),
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

    if (words.isEmpty) {
      // A command consisting solely of redirections is unusual; surface it as
      // a redirection-only invocation if any redirection was present.
      if (redirections.isEmpty) return null;
      return CommandInvocation(
        executable: '',
        redirections: redirections,
        substitutions: subs,
        environmentReferences: envs,
      );
    }

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

  /// Re-parses the inline command string of `sh -c "..."`/`bash -c '...'` into
  /// a nested AST, or returns `null` when this is not an inline-exec call (or
  /// the nesting limit is reached).
  CommandNode? _parseInlineCommand(String executable, List<String> arguments) {
    if (depth >= _maxInlineDepth) return null;
    final index = inlineScriptArgIndex(executable, arguments);
    if (index == null) return null;
    final script = arguments[index];
    if (script.isEmpty) return null;
    final innerDiagnostics = <ParseDiagnostic>[];
    final innerTokens = _ShellTokenizer(script, innerDiagnostics).tokenize();
    return _TokenParser(
      innerTokens,
      innerDiagnostics,
      depth: depth + 1,
    ).parseScript();
  }
}
