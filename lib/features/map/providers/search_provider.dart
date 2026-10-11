import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/place.dart';
import '../../../providers/map_service_provider.dart';
import '../utils/search_result_ranker.dart';

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
      final primary = _ref.read(searchServiceProvider);
      final secondary = _ref.read(secondarySearchServiceProvider);

      final responses = await Future.wait<List<Place>>([
        _safeSearch(
          primary,
          term: normalizedTerm,
          center: center,
        ),
        _safeSearch(
          secondary,
          term: normalizedTerm,
          center: center,
        ),
      ]);

      if (requestId != _requestId) return;

      final results = SearchResultRanker.mergeAndRank(
        query: normalizedTerm,
        center: center,
        primary: responses[0],
        secondary: responses[1],
      );

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

  Future<List<Place>> _safeSearch(
    dynamic service, {
    required String term,
    required LatLng center,
  }) async {
    try {
      return await service.search(
        term: term,
        center: center,
      );
    } catch (_) {
      return const [];
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
