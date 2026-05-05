import '../models/ae_result.dart';
import '../models/get_definition.dart';
import '../models/types.dart';
import 'ae_definition_service.dart';

class DefaultAeDefinitionService implements AeDefinitionService {
  const DefaultAeDefinitionService();

  @override
  AeResult<GetDefinitionOutput> getDefinition() => AeResult.ok(
        GetDefinitionOutput(
          name: 'Agentic Executables (AE)',
          description:
              'Libraries/packages managed by AI agents as executable programs for installation, configuration, usage, and uninstallation.',
          contexts: const {
            AeContext.library: AeDefinitionContext(
              description: 'Maintain AE files within the library itself',
              useCase: 'For library maintainers creating AE documentation',
            ),
            AeContext.project: AeDefinitionContext(
              description: 'Use AE in projects that depend on the library',
              useCase: 'For developers integrating libraries as AE',
            ),
          },
          actions: const [
            AeDefinitionAction(
              name: AeAction.bootstrap,
              description: 'Create/maintain AE files in a library',
              applicableContexts: [AeContext.library],
            ),
            AeDefinitionAction(
              name: AeAction.install,
              description: 'Add AE to a project',
              applicableContexts: [AeContext.library, AeContext.project],
            ),
            AeDefinitionAction(
              name: AeAction.uninstall,
              description: 'Remove AE from a project',
              applicableContexts: [AeContext.library, AeContext.project],
            ),
            AeDefinitionAction(
              name: AeAction.update,
              description: 'Update AE to a newer version',
              applicableContexts: [AeContext.library, AeContext.project],
            ),
            AeDefinitionAction(
              name: AeAction.use,
              description: 'Apply AE capabilities in the project',
              applicableContexts: [AeContext.library, AeContext.project],
            ),
          ],
          tools: const [
            AeDefinitionTool(
              name: 'ae_definition',
              description: 'Retrieve core AE definition and framework overview',
              useCase:
                  'Understand what AE is and which contexts/actions are available',
            ),
            AeDefinitionTool(
              name: 'ae_instructions',
              description:
                  'Retrieve contextual documentation for context+action combinations',
              useCase:
                  'Get detailed instructions for a specific context and action',
            ),
            AeDefinitionTool(
              name: 'ae_generate',
              description:
                  'Generate AE files via codex or deterministic templates',
              useCase: 'Create ae_install/uninstall/update/use assets',
            ),
            AeDefinitionTool(
              name: 'ae_registry',
              description:
                  'Submit libraries to registry or fetch published AE artifacts',
              useCase: 'Publisher and consumer registry workflows',
            ),
            AeDefinitionTool(
              name: 'ae_verify',
              description:
                  'Generate verification checklist based on AE principles',
              useCase: 'Verify implementation quality after making changes',
            ),
            AeDefinitionTool(
              name: 'ae_evaluate',
              description:
                  'Score implementation compliance with detailed feedback',
              useCase: 'Objective compliance evaluation with actionable fixes',
            ),
          ],
          usageGuide: const {
            'library_maintainers':
                'Use instructions(context="library", action="bootstrap") to create AE files, then registry submit to publish.',
            'project_developers':
                'Use registry get to fetch ae_install/ae_update/ae_use and apply in project context.',
            'workflow':
                'After implementation run verify first and evaluate second for measurable quality checks.',
          },
          corePrinciples: const [
            AeDefinitionPrinciple(
              name: 'Agent Empowerment',
              description:
                  'Equip AI agents with meta-rules to autonomously maintain, install, configure, integrate, use, and uninstall AEs based on project needs.',
            ),
            AeDefinitionPrinciple(
              name: 'Modularity',
              description:
                  'Structure AE instructions in clear, reusable steps: Installation -> Configuration -> Integration -> Usage -> Uninstallation.',
            ),
            AeDefinitionPrinciple(
              name: 'Contextual Awareness',
              description:
                  'Ensure AE documentation provides sufficient domain knowledge for agents to understand integration points without manual intervention.',
            ),
            AeDefinitionPrinciple(
              name: 'Reversibility',
              description:
                  'Design uninstallation to cleanly remove all traces of the AE, restoring the original state.',
            ),
            AeDefinitionPrinciple(
              name: 'Validation',
              description:
                  'Include checks for installation, configuration, and usage to ensure reliability and allow for corrections.',
            ),
            AeDefinitionPrinciple(
              name: 'Documentation Focus',
              description:
                  'Prioritize concise, agent-readable instructions over verbose human-oriented docs.',
            ),
          ],
          message:
              'AE v2 uses a shared core with CLI-first workflows and MCP as optional thin adapter.',
        ),
      );
}
