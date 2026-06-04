import '../syntax.dart';
import 'command_parser.dart';
import 'generic_parser.dart';
import 'powershell_parser.dart';
import 'shell_parser.dart';
import 'windows_cmd_parser.dart';

/// Resolves the [CommandParser] for a given [CommandSyntax].
///
/// All parsers are stateless and `const`, so resolution is cheap and the
/// returned instances can be shared.
abstract final class ParserFactory {
  static const GenericParser _generic = GenericParser();
  static const BashParser _bash = BashParser();
  static const PosixParser _posix = PosixParser();
  static const WindowsCmdParser _cmd = WindowsCmdParser();
  static const PowerShellParser _powershell = PowerShellParser();

  /// Returns the parser that understands [syntax].
  static CommandParser forSyntax(CommandSyntax syntax) => switch (syntax) {
    CommandSyntax.generic => _generic,
    CommandSyntax.posixShell => _posix,
    CommandSyntax.bash => _bash,
    CommandSyntax.windowsCmd => _cmd,
    CommandSyntax.powershell => _powershell,
  };
}
