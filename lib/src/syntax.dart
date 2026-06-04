/// The command-line syntax a raw command string is written in.
///
/// The chosen syntax controls which parser is used and therefore which shell
/// constructs (pipelines, chaining, substitution, redirection, environment
/// expansion) are recognised. See the individual parsers for details.
enum CommandSyntax {
  /// A minimal, expansion-free syntax intended for AI-agent terminal
  /// execution. Only tokenization is performed: no pipelines, chaining,
  /// redirection, substitution or environment expansion are interpreted.
  ///
  /// This is the safest syntax because shell metacharacters carry no special
  /// meaning and are surfaced verbatim for the security analyzer.
  generic,

  /// The POSIX shell command language (the portable subset of `bash`).
  posixShell,

  /// The GNU Bourne-Again Shell (`bash`), a superset of [posixShell].
  bash,

  /// The Windows Command Prompt (`cmd.exe`) batch syntax.
  windowsCmd,

  /// Microsoft PowerShell.
  powershell,
}
