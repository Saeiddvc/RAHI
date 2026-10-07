import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/place.dart';
import '../../../providers/map_service_provider.dart';

class SearchState {
  final String query;
  final bool isLoading;
  final List<Place> results;
  final String? error;

  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.results = const [],
    this.error,
  });

  SearchState copyWith({
    String? query,
    bool? isLoading,
    List<Place>? results,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._ref) : super(const SearchState());

  final Ref _ref;
  int _requestId = 0;

  Future<void> search(String term, LatLng center) async {
    final normalizedTerm = term.trim();

    if (normalizedTerm.isEmpty) {
      clear();
      return;
    }

    final requestId = ++_requestId;

    state = state.copyWith(
      query: normalizedTerm,
      isLoading: true,
      clearError: true,
    );

    try {
      final service = _ref.read(searchServiceProvider);
      final results = await service.search(
        term: normalizedTerm,
        center: center,
      );

      if (requestId != _requestId) return;

      state = state.copyWith(
        isLoading: false,
        results: results,
        clearError: true,
      );
    } catch (error) {
      if (requestId != _requestId) return;

      state = state.copyWith(
        isLoading: false,
        results: const [],
        error: error.toString(),
      );
    }
  }

  void clear() {
    _requestId++;
    state = const SearchState();
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
