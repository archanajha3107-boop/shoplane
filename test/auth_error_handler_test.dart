import 'package:flutter_test/flutter_test.dart';
import 'package:shoplane/services/auth_error_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  test('maps network auth failures to a friendly message', () {
    final error = FirebaseAuthException(code: 'network-request-failed', message: 'network error');

    expect(formatAuthError(error), contains('internet connection'));
  });

  test('maps duplicate email errors to a clear signup message', () {
    final error = FirebaseAuthException(code: 'email-already-in-use', message: 'email in use');

    expect(formatAuthError(error), contains('already registered'));
  });
}
