import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/core/constants/daily_call_prompt.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';

class MockGeminiLiveService extends Mock implements GeminiLiveService {}

void main() {
  late MockGeminiLiveService mockService;

  setUp(() {
    mockService = MockGeminiLiveService();

    when(
      () => mockService.transcriptStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockService.toolCallStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockService.stateStream).thenAnswer((_) => const Stream.empty());
    when(
      () => mockService.latencyStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockService.connect(
        systemPrompt: any(named: 'systemPrompt'),
        tools: any(named: 'tools'),
      ),
    ).thenAnswer((_) async {});
  });

  group('StartCall systemPrompt', () {
    test(
      'passes null systemPrompt by default (uses service default)',
      () async {
        final bloc = VoiceCallBloc(service: mockService);
        bloc.add(const StartCall());
        await Future.delayed(Duration.zero);

        verify(
          () => mockService.connect(systemPrompt: null, tools: null),
        ).called(1);

        await bloc.close();
      },
    );

    test('passes minimal prompt when systemPrompt is set', () async {
      final bloc = VoiceCallBloc(service: mockService);
      bloc.add(StartCall(systemPrompt: dailyCallMinimalPrompt));
      await Future.delayed(Duration.zero);

      verify(
        () => mockService.connect(
          systemPrompt: dailyCallMinimalPrompt,
          tools: null,
        ),
      ).called(1);

      await bloc.close();
    });

    test('passes detailed prompt when explicitly set', () async {
      final bloc = VoiceCallBloc(service: mockService);
      bloc.add(StartCall(systemPrompt: dailyCallSystemPrompt));
      await Future.delayed(Duration.zero);

      verify(
        () => mockService.connect(
          systemPrompt: dailyCallSystemPrompt,
          tools: null,
        ),
      ).called(1);

      await bloc.close();
    });
  });
}
