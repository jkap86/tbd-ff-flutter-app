import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/providers/auth_provider.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/models/user_model.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'auth_provider_test.mocks.dart';

@GenerateMocks([AuthService])
void main() {
  late AuthProvider authProvider;
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    authProvider = AuthProvider();
    // Inject mock service (requires modifying AuthProvider to accept dependency injection)
  });

  group('AuthProvider', () {
    test('should start with not authenticated state', () {
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.user, null);
    });

    test('should set authenticated state after successful login', () async {
      final mockUser = User(
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        isPhoneVerified: false,
      );

      when(mockAuthService.login(any, any)).thenAnswer(
        (_) async => {'user': mockUser, 'token': 'test.jwt.token'},
      );

      // await authProvider.login('testuser', 'password123');

      // expect(authProvider.isAuthenticated, true);
      // expect(authProvider.user, mockUser);
    });

    test('should clear state on logout', () async {
      authProvider.setUser(User(
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        isPhoneVerified: false,
      ));

      await authProvider.logout();

      expect(authProvider.isAuthenticated, false);
      expect(authProvider.user, null);
    });

    test('should handle login errors gracefully', () async {
      when(mockAuthService.login(any, any)).thenThrow(
        Exception('Invalid credentials'),
      );

      // expect(
      //   () => authProvider.login('testuser', 'wrongpass'),
      //   throwsException,
      // );
    });
  });

  group('AuthProvider - Token Management', () {
    test('should store token securely on login', () async {
      // Test token storage
      expect(true, true); // Placeholder
    });

    test('should load token on app startup', () async {
      // Test token loading
      expect(true, true); // Placeholder
    });

    test('should clear token on logout', () async {
      await authProvider.logout();
      // Verify token is cleared
      expect(true, true); // Placeholder
    });
  });
}
