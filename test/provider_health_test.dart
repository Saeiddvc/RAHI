import 'package:flutter_test/flutter_test.dart';
import 'package:rahi/core/services/provider_health.dart';

void main() {
  group('ProviderHealthNotifier', () {
    test('moves from degraded to down after repeated failures', () {
      final notifier = ProviderHealthNotifier();

      notifier.recordFailure(parsimap: true);
      expect(notifier.state.parsimap, ProviderHealth.degraded);

      notifier.recordFailure(parsimap: true);
      expect(notifier.state.parsimap, ProviderHealth.degraded);

      notifier.recordFailure(parsimap: true);
      expect(notifier.state.parsimap, ProviderHealth.down);
    });

    test('success restores provider health', () {
      final notifier = ProviderHealthNotifier();

      notifier.recordFailure(parsimap: false);
      expect(notifier.state.neshan, ProviderHealth.degraded);

      notifier.recordSuccess(parsimap: false);
      expect(notifier.state.neshan, ProviderHealth.healthy);
    });
  });
}
