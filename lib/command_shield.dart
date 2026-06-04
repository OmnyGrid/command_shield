/// command_shield — security-first command-line analysis.
///
/// Parse, normalize, classify, analyse and policy-validate shell commands into
/// ALLOW / REVIEW / DENY decisions **without ever executing them**. Designed
/// for AI agents, remote executors, CI/CD systems and sandboxed runners that
/// need an explainable, deterministic verdict before a command runs.
///
/// The typical entry point is `CommandShield`:
///
/// ```dart
/// import 'package:command_shield/command_shield.dart';
///
/// void main() {
///   final shield = CommandShield();
///   final result = shield.validate('git status', syntax: CommandSyntax.bash);
///   print(result.decision); // CommandDecision.allow
/// }
/// ```
///
/// > **Important.** Command validation reduces risk but is **not** a substitute
/// > for sandboxing, containers, least privilege or process isolation. Treat it
/// > as one defence-in-depth layer, never the only one.
library;

export 'src/analysis/analyzer.dart';
export 'src/analysis/command_analysis.dart';
export 'src/ast/command_node.dart';
export 'src/capabilities/capability.dart';
export 'src/capabilities/capability_detector.dart';
export 'src/capabilities/command_knowledge_base.dart';
export 'src/capabilities/knowledge/command_knowledge.dart';
export 'src/capabilities/knowledge/command_knowledge_plugin.dart';
export 'src/capabilities/knowledge/command_knowledge_result.dart';
export 'src/capabilities/knowledge/plugins/archive_knowledge.dart';
export 'src/capabilities/knowledge/plugins/container_knowledge.dart';
export 'src/capabilities/knowledge/plugins/dart_flutter_knowledge.dart';
export 'src/capabilities/knowledge/plugins/default_plugins.dart';
export 'src/capabilities/knowledge/plugins/environment_knowledge.dart';
export 'src/capabilities/knowledge/plugins/filesystem_knowledge.dart';
export 'src/capabilities/knowledge/plugins/git_knowledge.dart';
export 'src/capabilities/knowledge/plugins/network_knowledge.dart';
export 'src/capabilities/knowledge/plugins/package_manager_knowledge.dart';
export 'src/capabilities/knowledge/plugins/process_knowledge.dart';
export 'src/capabilities/knowledge/plugins/shell_knowledge.dart';
export 'src/capabilities/knowledge/plugins/system_config_knowledge.dart';
export 'src/capabilities/knowledge/plugins/windows_knowledge.dart';
export 'src/classification/effect.dart';
export 'src/classification/effect_classifier.dart';
export 'src/command_shield.dart';
export 'src/normalization/default_rules.dart';
export 'src/normalization/normalizer.dart';
export 'src/parser/command_parser.dart';
export 'src/parser/generic_parser.dart';
export 'src/parser/parse_diagnostic.dart';
export 'src/parser/parse_result.dart';
export 'src/parser/parser_factory.dart';
export 'src/parser/powershell_parser.dart';
export 'src/parser/shell_parser.dart';
export 'src/parser/windows_cmd_parser.dart';
export 'src/policies/argument_pattern_policy.dart';
export 'src/policies/command_policy.dart';
export 'src/policies/dangerous_character_policy.dart';
export 'src/policies/default_policy.dart';
export 'src/policies/environment_variable_expansion_policy.dart';
export 'src/policies/executable_allow_list_policy.dart';
export 'src/policies/executable_block_list_policy.dart';
export 'src/policies/length_limit_policy.dart';
export 'src/policies/path_traversal_policy.dart';
export 'src/policies/risk_threshold_policy.dart';
export 'src/policies/shell_execution_policy.dart';
export 'src/security/detectors/command_substitution_detector.dart';
export 'src/security/detectors/dangerous_operator_detector.dart';
export 'src/security/detectors/destructive_command_detector.dart';
export 'src/security/detectors/env_expansion_detector.dart';
export 'src/security/detectors/knowledge_risk_detector.dart';
export 'src/security/detectors/path_traversal_detector.dart';
export 'src/security/detectors/privilege_escalation_detector.dart';
export 'src/security/detectors/remote_exec_detector.dart';
export 'src/security/detectors/shell_execution_detector.dart';
export 'src/security/security_analyzer.dart';
export 'src/security/security_detector.dart';
export 'src/security/security_finding.dart';
export 'src/security/security_level.dart';
export 'src/syntax.dart';
export 'src/validation/command_decision.dart';
export 'src/validation/command_result.dart';
