import 'types.dart';

class AeDefinitionContext {
  const AeDefinitionContext({required this.description, required this.useCase});

  final String description;
  final String useCase;

  Map<String, dynamic> toJson() => {
        'description': description,
        'use_case': useCase,
      };
}

class AeDefinitionAction {
  const AeDefinitionAction({
    required this.name,
    required this.description,
    required this.applicableContexts,
  });

  final AeAction name;
  final String description;
  final List<AeContext> applicableContexts;

  Map<String, dynamic> toJson() => {
        'name': name.value,
        'description': description,
        'applicable_contexts': applicableContexts
            .map((final e) => e.value)
            .toList(growable: false),
      };
}

class AeDefinitionTool {
  const AeDefinitionTool({
    required this.name,
    required this.description,
    required this.useCase,
  });

  final String name;
  final String description;
  final String useCase;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'use_case': useCase,
      };
}

class AeDefinitionPrinciple {
  const AeDefinitionPrinciple({required this.name, required this.description});

  final String name;
  final String description;

  Map<String, dynamic> toJson() => {'name': name, 'description': description};
}

class GetDefinitionOutput {
  const GetDefinitionOutput({
    required this.name,
    required this.description,
    required this.contexts,
    required this.actions,
    required this.tools,
    required this.usageGuide,
    required this.corePrinciples,
    required this.message,
  });

  final String name;
  final String description;
  final Map<AeContext, AeDefinitionContext> contexts;
  final List<AeDefinitionAction> actions;
  final List<AeDefinitionTool> tools;
  final Map<String, String> usageGuide;
  final List<AeDefinitionPrinciple> corePrinciples;
  final String message;

  Map<String, dynamic> toJson() => {
        'definition': {'name': name, 'description': description},
        'contexts': {
          for (final entry in contexts.entries)
            entry.key.value: entry.value.toJson(),
        },
        'actions': actions.map((final e) => e.toJson()).toList(growable: false),
        'tools': tools.map((final e) => e.toJson()).toList(growable: false),
        'usage_guide': usageGuide,
        'core_principles':
            corePrinciples.map((final e) => e.toJson()).toList(growable: false),
        'message': message,
      };
}
