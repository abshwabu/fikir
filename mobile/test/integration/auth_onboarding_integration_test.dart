import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/features/auth/data/auth_repository.dart';
import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  MockHttpClientAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppConfig.initialize(
      const AppConfig(
        flavor: AppFlavor.dev,
        appName: 'Fikir Test',
        apiBaseUrl: 'http://localhost:8080',
        wsBaseUrl: 'ws://localhost:8080/ws',
        cdnBaseUrl: 'http://localhost:9000/public',
        enableLogging: false,
      ),
    );
  });

  test('Happy path: phone request -> verify OTP -> draft save -> submit onboarding',
      () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final memoryDb = AppDatabase(NativeDatabase.memory());
    addTearDown(memoryDb.close);

    final testDio = Dio(
      BaseOptions(baseUrl: 'http://localhost:8080'),
    );

    // Mock backend responses
    testDio.httpClientAdapter = MockHttpClientAdapter((options) async {
      final path = options.path;

      if (path.contains('/v1/auth/otp/request')) {
        return ResponseBody.fromString(
          '{"message": "OTP sent successfully"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      } else if (path.contains('/v1/auth/otp/verify')) {
        return ResponseBody.fromString(
          '{"access_token": "mock_access", "refresh_token": "mock_refresh", "user": {"id": "11111111-1111-1111-1111-111111111111"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      } else if (path.contains('/v1/me/profile')) {
        return ResponseBody.fromString(
          '{"id": "11111111-1111-1111-1111-111111111111", "display_name": "Kidus"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      } else if (path.contains('/v1/me/interests')) {
        return ResponseBody.fromString(
          '{"interests": ["🎷 Ethio Jazz", "☕ Coffee Ceremony (ቡና)", "🏃 Long-Distance Running"]}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      } else if (path.contains('/v1/me/location')) {
        return ResponseBody.fromString(
          '{"city": "Addis Ababa (Bole)", "latitude": 9.01, "longitude": 38.76}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }

      return ResponseBody.fromString('{}', 200);
    });

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dioProvider.overrideWithValue(testDio),
        databaseProvider.overrideWithValue(memoryDb),
      ],
    );
    addTearDown(container.dispose);

    final authRepo = container.read(authRepositoryProvider);
    final onboardingRepo = container.read(onboardingRepositoryProvider);

    // 1. Request OTP
    final reqResult = await authRepo.requestOtp('+251911223344');
    expect(reqResult.isSuccess, isTrue);

    // 2. Verify OTP
    final verifyResult = await authRepo.verifyOtp(
      phone: '+251911223344',
      code: '123456',
    );
    expect(verifyResult.isSuccess, isTrue);
    expect(container.read(authStateProvider), isTrue);

    // 3. Draft persistence: User fills name and birthdate, then app restarts
    var draftState = const OnboardingState(
      currentStep: 2,
      name: 'Kidus',
      gender: 'man',
      interestedIn: ['women'],
      interests: [
        '🎷 Ethio Jazz',
        '☕ Coffee Ceremony (ቡና)',
        '🏃 Long-Distance Running',
      ],
    );
    draftState = draftState.copyWith(birthdate: DateTime(1996, 4, 12));

    await onboardingRepo.saveDraft(draftState);

    // App killed & restored: Load draft from disk
    final loadedDraft = onboardingRepo.loadDraft();
    expect(loadedDraft.currentStep, equals(2));
    expect(loadedDraft.name, equals('Kidus'));
    expect(loadedDraft.birthdate, equals(DateTime(1996, 4, 12)));
    expect(loadedDraft.interests.length, equals(3));

    // 4. Submit onboarding
    final submitResult = await onboardingRepo.submitOnboarding(loadedDraft);
    expect(submitResult.isSuccess, isTrue);
    expect(onboardingRepo.isOnboardingComplete(), isTrue);
  });
}
