/// Base class for eval personas.
///
/// Each persona defines a user archetype that tests specific failure modes
/// in the AI conversation.
abstract class Persona {
  /// Short identifier used in file names and CLI args.
  String get id;

  /// Human-readable name.
  String get name;

  /// Description of the persona's behavior for the judge.
  String get description;

  /// System prompt that instructs Claude to play this persona.
  String get systemPrompt;

  /// What we expect the AI to do well/poorly with this persona.
  String get expectedBehavior;
}
