import 'package:flutter_test/flutter_test.dart';
import 'package:rahi/core/services/voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('VoiceService starts optimistic before the first platform probe', () {
    final service = VoiceService();

    // CI has no device TTS engine. Real availability is determined only after
    // the first platform call and remains a Device-Test responsibility.
    expect(service.isAvailable, isTrue);
  });
}
