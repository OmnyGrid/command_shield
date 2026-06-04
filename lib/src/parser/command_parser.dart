import '../syntax.dart';
import 'parse_result.dart';

/// Base class for all command parsers.
///
/// A parser converts a raw command string into a [ParseResult] containing a
/// best-effort AST and any diagnostics. Implementations **must not** throw on
/// malformed input and **must never execute** anything.
abstract class CommandParser {
  /// Const base constructor for subclasses.
  const CommandParser();

  /// The syntax this parser understands.
  CommandSyntax get syntax;

  /// Parses [raw] into a [ParseResult]. Always succeeds without throwing.
  ParseResult parse(String raw);
}

/// A lightweight, quote- and escape-aware word splitter shared by the parsers.
///
/// It understands single quotes (literal), double quotes (with backslash
/// escapes for `"` and `\`) and backslash escaping outside quotes. It does not
/// interpret operators, substitution or expansion — callers layer those on top.
class QuoteAwareSplitter {
  /// Creates a splitter.
  const QuoteAwareSplitter();

  /// Splits [input] into whitespace-separated words, honouring quoting and
  /// escaping. Quote characters are removed from the produced words.
  ///
  /// Unterminated quotes are tolerated: the remainder of the input is treated
  /// as part of the current word and reported via [onError].
  List<String> split(
    String input, {
    void Function(String message, int offset)? onError,
  }) {
    final words = <String>[];
    final buffer = StringBuffer();
    var inWord = false;
    var i = 0;
    final n = input.length;

    void flush() {
      if (inWord) {
        words.add(buffer.toString());
        buffer.clear();
        inWord = false;
      }
    }

    while (i < n) {
      final ch = input[i];
      if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
        flush();
        i++;
        continue;
      }
      if (ch == r'\') {
        inWord = true;
        if (i + 1 < n) {
          buffer.write(input[i + 1]);
          i += 2;
        } else {
          // Trailing backslash: keep it literally.
          buffer.write(ch);
          i++;
        }
        continue;
      }
      if (ch == "'") {
        inWord = true;
        final close = input.indexOf("'", i + 1);
        if (close < 0) {
          buffer.write(input.substring(i + 1));
          onError?.call('Unterminated single quote', i);
          i = n;
        } else {
          buffer.write(input.substring(i + 1, close));
          i = close + 1;
        }
        continue;
      }
      if (ch == '"') {
        inWord = true;
        i++;
        var closed = false;
        while (i < n) {
          final c = input[i];
          if (c == r'\' && i + 1 < n) {
            final next = input[i + 1];
            if (next == '"' || next == r'\' || next == r'$' || next == '`') {
              buffer.write(next);
              i += 2;
              continue;
            }
            buffer.write(c);
            i++;
            continue;
          }
          if (c == '"') {
            i++;
            closed = true;
            break;
          }
          buffer.write(c);
          i++;
        }
        if (!closed) {
          onError?.call('Unterminated double quote', i);
        }
        continue;
      }
      inWord = true;
      buffer.write(ch);
      i++;
    }
    flush();
    return words;
  }
}
