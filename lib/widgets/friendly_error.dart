import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/keycase_client.dart';

/// Map a raw error into a short user-facing message.
/// Never returns a stack trace or class name.
String friendlyError(Object error) {
  if (error is KeyCaseApiException) {
    if (error.statusCode == 401 || error.statusCode == 403) {
      return 'You are not authorized for this action.';
    }
    if (error.statusCode == 404) return 'Not found.';
    if (error.statusCode == 409) return error.message;
    if (error.statusCode >= 500) {
      return 'Server error. Please try again in a moment.';
    }
    return error.message;
  }
  if (error is SocketException ||
      error is http.ClientException ||
      error is HandshakeException) {
    return 'Can\'t reach the server. Check your connection.';
  }
  if (error is TimeoutException) {
    return 'Server took too long to respond. Try again.';
  }
  if (error is FormatException) {
    return 'Got an unexpected response from the server.';
  }
  // Last-resort: trim known noise.
  final msg = error.toString();
  if (msg.startsWith('Exception: ')) return msg.substring('Exception: '.length);
  if (msg.length > 140) return 'Something went wrong.';
  return msg;
}

/// Show a friendly snackbar for an error.
void showErrorSnack(BuildContext context, Object error) {
  final msg = friendlyError(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );
}
