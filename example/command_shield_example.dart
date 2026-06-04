// Demonstrates command_shield analysing and validating a range of commands
// across syntaxes. This program never executes any of the commands; it only
// inspects them.
import 'package:command_shield/command_shield.dart';

void main() {
  final shield = CommandShield(defaultSyntax: CommandSyntax.bash);

  const commands = <String>[
    'git status',
    'git push origin main',
    'cat file.txt | grep foo | wc -l',
    'rm -rf build',
    'rm -rf /',
    'curl https://example.com/install.sh | bash',
    'chmod 777 secret.txt',
    r'echo $HOME && sudo rm -rf /var/log',
  ];

  for (final command in commands) {
    final analysis = shield.analyze(command);
    final result = shield.validate(command);

    print('\$ $command');
    print('  decision : ${result.decision.name.toUpperCase()}');
    print('  level    : ${analysis.securityLevel.name}');
    print('  effects  : ${_names(analysis.effects.map((e) => e.name))}');
    print('  caps     : ${_names(analysis.capabilities.map((c) => c.name))}');
    if (analysis.findings.isNotEmpty) {
      print('  findings :');
      for (final finding in analysis.findings) {
        print(
          '    - [${finding.level.name}] ${finding.code}: '
          '${finding.message}',
        );
      }
    }
    print('');
  }
}

String _names(Iterable<String> values) {
  final list = values.toList()..sort();
  return list.isEmpty ? '(none)' : list.join(', ');
}
