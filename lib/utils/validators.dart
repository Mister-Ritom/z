import 'dart:core';

class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]{1,15}$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores (max 15 chars)';
    }
    return null;
  }

  static String? zap(String? value) {
    if (value == null || value.isEmpty) {
      return 'Zap cannot be empty';
    }
    if (value.length > 280) {
      return 'Zap cannot exceed 280 characters';
    }
    return null;
  }
}
