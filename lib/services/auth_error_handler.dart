import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

String formatAuthError(Object error) {
  // Firebase's reCAPTCHA-protected auth flow sometimes wraps the real
  // FirebaseAuthException inside another exception object rather than
  // throwing it directly. If the error's own string representation
  // contains the standard Firebase error patterns, extract the real
  // meaning here BEFORE falling through to the generic fallback.
  final errorString = error.toString().toLowerCase();
  if (errorString.contains('email address is already in use') ||
      errorString.contains('email-already-in-use')) {
    return 'This email is already registered. Please log in instead.';
  }
  if (errorString.contains('wrong-password') ||
      errorString.contains('invalid-credential') ||
      errorString.contains('user-not-found')) {
    return 'Incorrect email or password.';
  }
  if (errorString.contains('weak-password')) {
    return 'Please use a stronger password with at least 6 characters.';
  }
  if (errorString.contains('network')) {
    return 'We could not reach Firebase. Please check your internet connection and try again in a moment.';
  }

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
  } else if (error is FirebaseException) {
    // THIS CASE WAS MISSING — cloud_firestore throws its own FirebaseException,
    // a completely different type from FirebaseAuthException. Without this
    // branch, a rejected Firestore write (e.g. from security rules) fell
    // straight through to the generic "Something went wrong" message below,
    // hiding the real cause (e.g. 'permission-denied').
    switch (error.code) {
      case 'permission-denied':
        return 'Account created, but saving your profile was blocked by security rules (permission-denied). Please check Firestore rules for the "users" collection.';
      case 'unavailable':
        return 'Could not reach the database. Please check your internet connection and try again.';
      default:
        return 'Database error while saving your profile (${error.code}). ${error.message ?? ""}';
    }
  } else if (error is PlatformException) {
    switch (error.code) {
      case 'network_error':
        return 'We could not reach Firebase. Please check your internet connection and try again in a moment.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }

  // Last-resort fallback — now includes the raw error so it's never
  // completely silent, even for a truly unanticipated exception type.
  return 'Something went wrong. Please try again. (${error.runtimeType}: $error)';
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}