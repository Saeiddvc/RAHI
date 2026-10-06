import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ProviderHealth {
  unknown,
  healthy,
  degraded,
  down,
}

class ProviderHealthState {
  final ProviderHealth parsimap;
  final ProviderHealth neshan;
  final DateTime? lastFailure;

  const ProviderHealthState({
    this.parsimap = ProviderHealth.unknown,
    this.neshan = ProviderHealth.unknown,
    this.lastFailure,
  });

  ProviderHealthState copyWith({
    ProviderHealth? parsimap,
    ProviderHealth? neshan,
    DateTime? lastFailure,
  }) {
    return ProviderHealthState(
      parsimap: parsimap ?? this.parsimap,
      neshan: neshan ?? this.neshan,
      lastFailure: lastFailure ?? this.lastFailure,
    );
  }
}

class ProviderHealthNotifier extends StateNotifier<ProviderHealthState> {
  ProviderHealthNotifier() : super(const ProviderHealthState());

  static const Duration _window = Duration(minutes: 2);

  DateTime? _parsimapLastFailure;
  DateTime? _neshanLastFailure;
  int _parsimapFailures = 0;
  int _neshanFailures = 0;

  void recordSuccess({required bool parsimap}) {
    _expireOldFailures(DateTime.now());

    if (parsimap) {
      _parsimapFailures = 0;
      _parsimapLastFailure = null;
      state = state.copyWith(parsimap: ProviderHealth.healthy);
    } else {
      _neshanFailures = 0;
      _neshanLastFailure = null;
      state = state.copyWith(neshan: ProviderHealth.healthy);
    }
  }

  void recordFailure({required bool parsimap}) {
    final now = DateTime.now();
    _expireOldFailures(now);

    if (parsimap) {
      _parsimapFailures++;
      _parsimapLastFailure = now;
      state = state.copyWith(
        parsimap: _healthFor(_parsimapFailures),
        lastFailure: now,
      );
    } else {
      _neshanFailures++;
      _neshanLastFailure = now;
      state = state.copyWith(
        neshan: _healthFor(_neshanFailures),
        lastFailure: now,
      );
    }
  }

  ProviderHealth _healthFor(int failures) {
    return failures >= 3 ? ProviderHealth.down : ProviderHealth.degraded;
  }

  void _expireOldFailures(DateTime now) {
    var parsimap = state.parsimap;
    var neshan = state.neshan;
    var changed = false;

    if (_parsimapLastFailure != null &&
        now.difference(_parsimapLastFailure!) > _window) {
      _parsimapFailures = 0;
      _parsimapLastFailure = null;
      if (parsimap != ProviderHealth.healthy) {
        parsimap = ProviderHealth.unknown;
        changed = true;
      }
    }

    if (_neshanLastFailure != null &&
        now.difference(_neshanLastFailure!) > _window) {
      _neshanFailures = 0;
      _neshanLastFailure = null;
      if (neshan != ProviderHealth.healthy) {
        neshan = ProviderHealth.unknown;
        changed = true;
      }
    }

    if (changed) {
      state = state.copyWith(parsimap: parsimap, neshan: neshan);
    }
  }
}

final providerHealthProvider =
    StateNotifierProvider<ProviderHealthNotifier, ProviderHealthState>(
  (ref) => ProviderHealthNotifier(),
);
