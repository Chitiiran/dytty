import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevSettingsState extends Equatable {
  final bool useMinimalPrompt;

  const DevSettingsState({this.useMinimalPrompt = false});

  DevSettingsState copyWith({bool? useMinimalPrompt}) {
    return DevSettingsState(
      useMinimalPrompt: useMinimalPrompt ?? this.useMinimalPrompt,
    );
  }

  @override
  List<Object?> get props => [useMinimalPrompt];
}

class DevSettingsCubit extends Cubit<DevSettingsState> {
  static const _keyUseMinimalPrompt = 'dev_use_minimal_prompt';

  DevSettingsCubit() : super(const DevSettingsState());

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final useMinimal = prefs.getBool(_keyUseMinimalPrompt) ?? false;
    emit(DevSettingsState(useMinimalPrompt: useMinimal));
  }

  Future<void> togglePromptVariant() async {
    final newValue = !state.useMinimalPrompt;
    emit(state.copyWith(useMinimalPrompt: newValue));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseMinimalPrompt, newValue);
  }
}
