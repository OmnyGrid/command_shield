import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about commands that change system or security configuration.
final class SystemConfigKnowledge implements CommandKnowledgePlugin {
  /// Creates the system-configuration knowledge plugin.
  const SystemConfigKnowledge();

  @override
  String get name => 'system';

  @override
  List<CommandKnowledge> get entries => simpleEntries(
    const [
      'chmod',
      'chown',
      'chgrp',
      'chattr',
      'mount',
      'umount',
      'useradd',
      'userdel',
      'usermod',
      'groupadd',
      'passwd',
      'systemctl',
      'service',
      'launchctl',
      'setfacl',
      'sysctl',
      'reg',
      'netsh',
      'defaults',
      'crontab',
      'iptables',
      'ufw',
      'firewall-cmd',
      'set-itemproperty',
      'new-service',
      'set-acl',
      'setx',
    ],
    KnowledgeCategory.system,
    const {CommandCapability.systemConfiguration},
  );
}
