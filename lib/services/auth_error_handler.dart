import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

String formatAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please log in instead.';
      case 'weak-password':
        return 'Please use a stronger password with at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled in Firebase. Please enable it in the Firebase console.';
      case 'network-request-failed':
      case 'too-many-requests':
        return 'We could not reach Firebase. Please check your internet connection and try again in a moment.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
    }
  } else if (error is PlatformException) {
    switch (error.code) {
      case 'network_error':
        return 'We could not reach Firebase. Please check your internet connection and try again in a moment.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }

  return 'Something went wrong. Please try again.';
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
