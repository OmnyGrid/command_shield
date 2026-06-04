import 'normalizer.dart';

/// Removes any leading directory component from an executable path.
///
/// `/usr/bin/rm` → `rm`, `C:\\Windows\\System32\\cmd.exe` → `cmd.exe`.
final NormalizationRule stripDirectoryRule = NormalizationRule(
  name: 'strip-directory',
  description: 'Removes a leading directory path, keeping only the basename.',
  apply: (executable) {
    final slash = executable.lastIndexOf('/');
    final backslash = executable.lastIndexOf(r'\');
    final cut = slash > backslash ? slash : backslash;
    if (cut < 0 || cut == executable.length - 1) return executable;
    return executable.substring(cut + 1);
  },
);

/// Strips common Windows executable/script extensions.
///
/// `powershell.exe` → `powershell`, `setup.cmd` → `setup`.
final NormalizationRule stripWindowsExtensionRule = NormalizationRule(
  name: 'strip-windows-extension',
  description: 'Removes a trailing .exe/.cmd/.bat/.com/.ps1 extension.',
  apply: (executable) {
    final match = RegExp(
      r'\.(exe|cmd|bat|com|ps1)$',
      caseSensitive: false,
    ).firstMatch(executable);
    if (match == null) return executable;
    return executable.substring(0, match.start);
  },
);

/// Collapses versioned interpreter names to their base name.
///
/// `python3` → `python`, `python2.7` → `python`, `pip3` → `pip`,
/// `node18` → `node`.
final NormalizationRule versionSuffixRule = NormalizationRule(
  name: 'strip-version-suffix',
  description: 'Removes a trailing version suffix from known interpreters.',
  apply: (executable) {
    const versioned = <String>{'python', 'pip', 'ruby', 'node', 'php', 'perl'};
    final match = RegExp(r'^([A-Za-z]+?)[0-9][0-9.]*$').firstMatch(executable);
    if (match == null) return executable;
    final base = match.group(1)!;
    return versioned.contains(base.toLowerCase()) ? base : executable;
  },
);

/// Maps known executable aliases to a canonical command name.
final NormalizationRule aliasRule = NormalizationRule(
  name: 'alias',
  description: 'Maps known aliases to their canonical command.',
  apply: (executable) {
    const aliases = <String, String>{
      'pwsh': 'powershell',
      'g++': 'gcc',
      'vi': 'vim',
      'fetch': 'curl',
    };
    return aliases[executable.toLowerCase()] ?? executable;
  },
);

/// The built-in, ordered normalization rules used by [Normalizer.standard].
///
/// Order matters: directory and extension are stripped before version suffixes
/// and aliases are resolved.
final List<NormalizationRule> defaultNormalizationRules =
    List<NormalizationRule>.unmodifiable(<NormalizationRule>[
      stripDirectoryRule,
      stripWindowsExtensionRule,
      versionSuffixRule,
      aliasRule,
    ]);
