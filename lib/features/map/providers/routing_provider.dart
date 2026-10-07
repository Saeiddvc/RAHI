import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/map_service.dart';
import '../../../data/models/map_route.dart';
import '../../../data/models/place.dart';
import '../../../providers/map_service_provider.dart';

class RoutingState {
  final Place? destination;
  final List<MapRoute> routes;
  final int selectedIndex;
  final bool isLoading;
  final String? error;

  const RoutingState({
    this.destination,
    this.routes = const [],
    this.selectedIndex = 0,
    this.isLoading = false,
    this.error,
  });

  MapRoute? get selectedRoute {
    if (routes.isEmpty ||
        selectedIndex < 0 ||
        selectedIndex >= routes.length) {
      return null;
    }
    return routes[selectedIndex];
  }

  bool get hasRoutes => routes.isNotEmpty;

  RoutingState copyWith({
    Place? destination,
    List<MapRoute>? routes,
    int? selectedIndex,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearAll = false,
  }) {
    if (clearAll) return const RoutingState();

    return RoutingState(
      destination: destination ?? this.destination,
      routes: routes ?? this.routes,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RoutingNotifier extends StateNotifier<RoutingState> {
  RoutingNotifier(this._ref) : super(const RoutingState());

  final Ref _ref;
  int _requestId = 0;

  Future<void> calculateRoute({
    required LatLng origin,
    required Place destination,
    required RouteType type,
  }) async {
    final requestId = ++_requestId;

    state = state.copyWith(
      destination: destination,
      isLoading: true,
      routes: const [],
      selectedIndex: 0,
      clearError: true,
    );

    try {
      final service = _ref.read(routingServiceProvider);

      if (!service.supportedRouteTypes.contains(type)) {
        throw MapServiceException(
          'نوع مسیر ${type.name} توسط ${service.displayName} پشتیبانی نمی‌شود.',
        );
      }

      final routes = await service.direction(
        origin: origin,
        destination: destination.location,
        type: type,
      );

      if (requestId != _requestId) return;

      if (routes.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'مسیری یافت نشد.',
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        routes: routes,
        selectedIndex: 0,
        clearError: true,
      );
    } catch (error) {
      if (requestId != _requestId) return;

      state = state.copyWith(
        isLoading: false,
        routes: const [],
        error: error.toString(),
      );
    }
  }

  void selectRoute(int index) {
    if (index >= 0 && index < state.routes.length) {
      state = state.copyWith(selectedIndex: index);
    }
  }

  void clear() {
    _requestId++;
    state = state.copyWith(clearAll: true);
  }
}

final routingProvider =
    StateNotifierProvider<RoutingNotifier, RoutingState>((ref) {
  return RoutingNotifier(ref);
});
