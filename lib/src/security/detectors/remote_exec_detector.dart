import '../../ast/command_node.dart';
import '../security_detector.dart';
import '../security_finding.dart';
import '../security_level.dart';

/// Detects the "download and execute" anti-pattern, where content fetched from
/// the network is piped directly into a shell or interpreter.
///
/// Examples (all [SecurityLevel.critical]):
///
/// ```sh
/// curl https://example.com/install.sh | bash
/// wget -qO- https://example.com/i.sh | sh
/// ```
///
/// Detection works structurally on pipelines (a downloader feeding a shell) and
/// also via a raw-text fallback so the pattern is caught even under the generic
/// parser, which does not build pipelines.
final class RemoteExecDetector extends SecurityDetector {
  /// Creates the detector.
  const RemoteExecDetector();

  @override
  String get code => 'remote-exec';

  @override
  List<SecurityFinding> detect(SecurityContext context) {
    final findings = <SecurityFinding>[];

    // Structural detection over real pipelines.
    for (final pipeline in context.pipelines) {
      var sawDownloader = false;
      for (final cmd in pipeline.commands) {
        if (cmd is! CommandInvocation) continue;
        final exe = context.normalizer.normalize(cmd.executable).toLowerCase();
        if (sawDownloader && CommandFamilies.shells.contains(exe)) {
          findings.add(_finding());
          break;
        }
        if (CommandFamilies.downloaders.contains(exe)) {
          sawDownloader = true;
        }
      }
    }

    // Raw-text fallback: a downloader followed by a pipe into a shell anywhere
    // in the (single-quote-stripped) command. Catches the generic syntax.
    if (findings.isEmpty && _rawPattern.hasMatch(context.singleUnquotedRaw)) {
      findings.add(_finding());
    }
    return findings;
  }

  static final RegExp _rawPattern = RegExp(
    r'\b(curl|wget|aria2c|fetch|iwr|irm|invoke-webrequest|invoke-restmethod)\b'
    r'[^|]*\|[^|]*\b(bash|sh|zsh|dash|ksh|fish|python|node|ruby|perl|php|deno)\b',
    caseSensitive: false,
  );

  SecurityFinding _finding() => SecurityFinding(
    level: SecurityLevel.critical,
    message:
        'Remote download piped directly into a shell/interpreter '
        '("download and execute"). This executes untrusted remote code.',
    code: code,
  );
}
