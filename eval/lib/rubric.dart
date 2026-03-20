/// Scoring dimensions for the AI conversation quality judge.
///
/// Each dimension is scored 1-5 by the Claude judge session.
enum Dimension {
  conversationalDepth('Conversational Depth', 'Depth'),
  questionVariety('Question Variety', 'Variety'),
  transitionQuality('Transition Quality', 'Trans'),
  multiCategoryAwareness('Multi-Category Awareness', 'Multi'),
  relationalWarmth('Relational Warmth', 'Warmth'),
  toolCallAccuracy('Tool Call Accuracy', 'Tools'),
  conversationPacing('Conversation Pacing', 'Pace');

  final String label;
  final String shortLabel;

  const Dimension(this.label, this.shortLabel);
}

/// Scores for a single eval run.
class EvalScores {
  final Map<Dimension, int> scores;
  final String judgeNotes;
  final List<int> flaggedTurns;

  const EvalScores({
    required this.scores,
    this.judgeNotes = '',
    this.flaggedTurns = const [],
  });

  double get average {
    if (scores.isEmpty) return 0;
    return scores.values.reduce((a, b) => a + b) / scores.length;
  }

  Map<String, dynamic> toJson() => {
    'scores': {
      for (final entry in scores.entries) entry.key.name: entry.value,
    },
    'average': double.parse(average.toStringAsFixed(1)),
    'judge_notes': judgeNotes,
    'flagged_turns': flaggedTurns,
  };

  factory EvalScores.fromJson(Map<String, dynamic> json) {
    final scoresMap = json['scores'] as Map<String, dynamic>;
    return EvalScores(
      scores: {
        for (final dim in Dimension.values)
          if (scoresMap.containsKey(dim.name))
            dim: scoresMap[dim.name] as int,
      },
      judgeNotes: json['judge_notes'] as String? ?? '',
      flaggedTurns: (json['flagged_turns'] as List<dynamic>?)
              ?.cast<int>() ??
          [],
    );
  }
}

/// The full judge prompt template.
///
/// Placeholders: {transcript}, {tool_calls}, {persona_description}
const judgeSystemPrompt = '''
You are an expert evaluator of AI conversation quality. You will be given a
transcript of a conversation between an AI journaling companion ("Dytty") and
a user, along with any tool calls the AI made and a description of the user
persona.

Score the AI's performance on these 7 dimensions (1-5 each):

1. **Conversational Depth** (1-5)
   1 = Accepts surface answers, never probes deeper
   3 = Occasionally asks follow-ups on interesting topics
   5 = Consistently explores topics with genuine curiosity, asks "why" and "how"

2. **Question Variety** (1-5)
   1 = Asks the same question pattern repeatedly ("How about X?" for every category)
   3 = Mix of question types but some repetition
   5 = Diverse question styles — open-ended, specific, reflective, playful

3. **Transition Quality** (1-5)
   1 = Mechanical category-by-category march ("Now let's talk about gratitude")
   3 = Some natural transitions but category structure still visible
   5 = Topics flow organically, categories emerge from conversation naturally

4. **Multi-Category Awareness** (1-5)
   1 = Misses entries that span multiple categories, saves only one
   3 = Catches obvious multi-category content sometimes
   5 = Reliably identifies and saves entries across categories from single responses

5. **Relational Warmth** (1-5)
   1 = Clinical interviewer — questions without connection
   3 = Polite and empathetic but still feels like a structured session
   5 = Feels like talking to a caring friend who remembers and connects threads

6. **Tool Call Accuracy** (1-5)
   1 = Misses most save-worthy content or saves irrelevant things
   3 = Saves key entries but misses some or miscategorizes
   5 = Accurately captures all meaningful content with correct categories

7. **Conversation Pacing** (1-5)
   1 = Too fast (rushing) or too slow (dragging topics out)
   3 = Acceptable pace with minor issues
   5 = Natural rhythm, knows when to move on and when to stay

## Persona Description
{persona_description}

## Transcript
{transcript}

## Tool Calls
{tool_calls}

## Instructions
Respond with ONLY a JSON object in this exact format:
```json
{
  "scores": {
    "conversationalDepth": <1-5>,
    "questionVariety": <1-5>,
    "transitionQuality": <1-5>,
    "multiCategoryAwareness": <1-5>,
    "relationalWarmth": <1-5>,
    "toolCallAccuracy": <1-5>,
    "conversationPacing": <1-5>
  },
  "judge_notes": "<2-3 sentence summary of key strengths and weaknesses>",
  "flagged_turns": [<turn numbers where quality was notably poor>]
}
```
''';
