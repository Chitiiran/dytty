import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/data/repositories/journal_repository.dart';

class SettingsState extends Equatable {
  final bool hideEntries;
  final bool loaded;

  const SettingsState({
    this.hideEntries = false,
    this.loaded = false,
  });

  SettingsState copyWith({bool? hideEntries, bool? loaded}) {
    return SettingsState(
      hideEntries: hideEntries ?? this.hideEntries,
      loaded: loaded ?? this.loaded,
    );
  }

  @override
  List<Object?> get props => [hideEntries, loaded];
}

class SettingsCubit extends Cubit<SettingsState> {
  final JournalRepository _repository;

  SettingsCubit({required JournalRepository repository})
      : _repository = repository,
        super(const SettingsState());

  Future<void> loadSettings() async {
    try {
      final settings = await _repository.getUserSettings();
      emit(SettingsState(
        hideEntries: settings['hideEntries'] as bool? ?? false,
        loaded: true,
      ));
    } catch (_) {
      emit(state.copyWith(loaded: true));
    }
  }

  Future<void> toggleHideEntries() async {
    final newValue = !state.hideEntries;
    emit(state.copyWith(hideEntries: newValue));
    try {
      await _repository.updateUserSettings({'hideEntries': newValue});
    } catch (_) {
      // Revert on failure
      emit(state.copyWith(hideEntries: !newValue));
    }
  }
}
