import 'dart:io';

import 'package:dytty_eval/orchestrator.dart';
import 'package:dytty_eval/personas/persona.dart';
import 'package:dytty_eval/personas/resistant_raj.dart';
import 'package:dytty_eval/personas/terse_tal.dart';
import 'package:dytty_eval/personas/verbose_vicky.dart';

final allPersonas = <String, Persona>{
  'terse_tal': TerseTal(),
  'verbose_vicky': VerboseVicky(),
  'resistant_raj': ResistantRaj(),
};

void main(List<String> args) async {
  final config = _parseArgs(args);
  if (config == null) return;

  final orchestrator = Orchestrator(
    maxTurns: config.maxTurns,
    promptVersion: config.promptVersion,
  );

  if (config.personas.length == 1) {
    await orchestrator.run(config.personas.first);
  } else {
    await orchestrator.runAll(config.personas);
  }
}

class _Config {
  final List<Persona> personas;
  final int maxTurns;
  final String promptVersion;

  const _Config({
    required this.personas,
    this.maxTurns = 20,
    this.promptVersion = 'v1-current',
  });
}

_Config? _parseArgs(List<String> args) {
  final personas = <Persona>[];
  var maxTurns = 20;
  var promptVersion = 'v1-current';

  var i = 0;
  while (i < args.length) {
    switch (args[i]) {
      case '--persona':
      case '-p':
        i++;
        if (i >= args.length) {
          _printUsage('Missing persona name after ${args[i - 1]}');
          return null;
        }
        final persona = allPersonas[args[i]];
        if (persona == null) {
          _printUsage('Unknown persona: ${args[i]}');
          return null;
        }
        personas.add(persona);

      case '--all':
        personas.addAll(allPersonas.values);

      case '--max-turns':
      case '-t':
        i++;
        if (i >= args.length) {
          _printUsage('Missing value after ${args[i - 1]}');
          return null;
        }
        maxTurns = int.tryParse(args[i]) ?? 20;

      case '--prompt-version':
        i++;
        if (i >= args.length) {
          _printUsage('Missing value after ${args[i - 1]}');
          return null;
        }
        promptVersion = args[i];

      case '--help':
      case '-h':
        _printUsage();
        return null;

      default:
        _printUsage('Unknown argument: ${args[i]}');
        return null;
    }
    i++;
  }

  if (personas.isEmpty) {
    _printUsage('Specify at least one persona with --persona or --all');
    return null;
  }

  return _Config(
    personas: personas,
    maxTurns: maxTurns,
    promptVersion: promptVersion,
  );
}

void _printUsage([String? error]) {
  if (error != null) {
    stderr.writeln('Error: $error\n');
  }
  print('''
Usage: dart run eval/bin/run_eval.dart [options]

Options:
  --persona, -p <name>    Run eval for a specific persona
                          Available: ${allPersonas.keys.join(', ')}
  --all                   Run eval for all personas
  --max-turns, -t <n>     Maximum conversation turns (default: 20)
  --prompt-version <ver>  Label for prompt version tracking (default: v1-current)
  --help, -h              Show this help

Examples:
  dart run eval/bin/run_eval.dart --persona terse_tal
  dart run eval/bin/run_eval.dart --all --max-turns 15
  dart run eval/bin/run_eval.dart -p terse_tal -p verbose_vicky
''');
}
