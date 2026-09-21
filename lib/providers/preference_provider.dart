// lib/providers/preference_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_preferences.dart';

class PreferenceNotifier extends StateNotifier<UserPreferences> {
  PreferenceNotifier() : super(UserPreferences());

  void updatePreferences(UserPreferences newPrefs) {
    state = newPrefs;
  }
}

final preferenceProvider =
StateNotifierProvider<PreferenceNotifier, UserPreferences>((ref) {
  return PreferenceNotifier();
});