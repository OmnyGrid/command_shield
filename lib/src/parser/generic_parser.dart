import '../ast/command_node.dart';
import '../syntax.dart';
import 'command_parser.dart';
import 'parse_diagnostic.dart';
import 'parse_result.dart';

/// The safest parser: pure tokenization with no interpretation of shell
/// metacharacters.
///
/// Intended for AI-agent terminal execution where commands are expected to be
/// simple invocations. Pipelines, chaining, redirection, command substitution
/// and environment expansion are **not** interpreted — any such characters are
/// preserved verbatim as ordinary tokens so that the security analyzer can
/// still flag them from the raw input.
final class GenericParser extends CommandParser {
  /// Creates a generic parser.
  const GenericParser();

  static const QuoteAwareSplitter _splitter = QuoteAwareSplitter();

  @override
  CommandSyntax get syntax => CommandSyntax.generic;

  @override
  ParseResult parse(String raw) {
    final diagnostics = <ParseDiagnostic>[];
    final words = _splitter.split(
      raw,
      onError: (message, offset) =>
          diagnostics.add(ParseDiagnostic.warning(message, offset: offset)),
    );

    if (words.isEmpty) {
      diagnostics.add(const ParseDiagnostic.info('Empty command'));
      return ParseResult(
        raw: raw,
        syntax: syntax,
        ast: null,
        diagnostics: diagnostics,
      );
    }

    final invocation = CommandInvocation(
      executable: words.first,
      arguments: words.sublist(1),
    );
    return ParseResult(
      raw: raw,
      syntax: syntax,
      ast: invocation,
      diagnostics: diagnostics,
    );
  }
}
