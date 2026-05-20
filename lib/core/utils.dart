import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:crisis_link/core/constants.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Date / Time Formatting Helpers
// ──────────────────────────────────────────────────────────────────────────────

/// Formats a [DateTime] as `"May 20, 2026"`.
String formatDate(DateTime date) {
  return DateFormat.yMMMd().format(date);
}

/// Formats a [DateTime] as `"12:30 PM"`.
String formatTime(DateTime date) {
  return DateFormat.jm().format(date);
}

/// Formats a [DateTime] as `"May 20, 2026 – 12:30 PM"`.
String formatDateTime(DateTime date) {
  return '${formatDate(date)} – ${formatTime(date)}';
}

/// Returns a human-friendly relative string such as *"2 minutes ago"*,
/// *"Yesterday"*, or falls back to a full date when older than 7 days.
String formatTimeAgo(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inSeconds < 60) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    final m = difference.inMinutes;
    return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
  } else if (difference.inHours < 24) {
    final h = difference.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  } else if (difference.inDays == 1) {
    return 'Yesterday';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} days ago';
  } else {
    return formatDate(date);
  }
}

/// Formats a [DateTime] as `"May 20, 12:30 PM"` — useful for compact cards.
String formatShortDateTime(DateTime date) {
  return DateFormat('MMM d, h:mm a').format(date);
}

// ──────────────────────────────────────────────────────────────────────────────
// Base64 Image Helpers
// ──────────────────────────────────────────────────────────────────────────────

/// Encodes raw image bytes to a Base64 string.
String encodeImageToBase64(Uint8List imageBytes) {
  return base64Encode(imageBytes);
}

/// Decodes a Base64 string back to raw image bytes.
Uint8List decodeBase64ToImage(String base64String) {
  return base64Decode(base64String);
}

/// Returns a [MemoryImage] provider from a Base64-encoded image string.
ImageProvider imageFromBase64(String base64String) {
  final bytes = decodeBase64ToImage(base64String);
  return MemoryImage(bytes);
}

/// Returns `true` if [value] looks like a valid Base64 image payload.
bool isValidBase64Image(String value) {
  if (value.isEmpty) return false;
  try {
    final bytes = base64Decode(value);
    return bytes.isNotEmpty;
  } catch (_) {
    return false;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Form Validation Helpers
// ──────────────────────────────────────────────────────────────────────────────

/// Validates that a field is non-empty.
String? validateRequired(String? value, [String fieldName = 'This field']) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName is required';
  }
  return null;
}

/// Validates a simple email pattern.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email is required';
  }
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
  );
  if (!emailRegex.hasMatch(value.trim())) {
    return 'Enter a valid email address';
  }
  return null;
}

/// Validates password strength.
/// Requires at least 8 characters, one uppercase letter, one digit.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Password must contain at least one uppercase letter';
  }
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'Password must contain at least one number';
  }
  return null;
}

/// Validates that a confirm-password field matches the original password.
String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'Please confirm your password';
  }
  if (value != password) {
    return 'Passwords do not match';
  }
  return null;
}

/// Validates a phone number (basic check: digits only, 7-15 length).
String? validatePhone(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null; // phone is optional
  }
  final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  if (cleaned.length < 7 || cleaned.length > 15 || !RegExp(r'^\d+$').hasMatch(cleaned)) {
    return 'Enter a valid phone number';
  }
  return null;
}

// ──────────────────────────────────────────────────────────────────────────────
// Location / Distance Helpers
// ──────────────────────────────────────────────────────────────────────────────

/// Calculates the approximate distance between two geographic coordinates
/// using the **Haversine formula**. Returns the result in **kilometres**.
double calculateDistanceKm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double earthRadiusKm = 6371.0;

  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusKm * c;
}

/// Returns a human-readable distance string: `"1.2 km"` or `"350 m"`.
String formatDistance(double distanceKm) {
  if (distanceKm < 1) {
    return '${(distanceKm * 1000).round()} m';
  }
  return '${distanceKm.toStringAsFixed(1)} km';
}

double _degToRad(double deg) => deg * (pi / 180.0);

// ──────────────────────────────────────────────────────────────────────────────
// Severity Color Helper (standalone – mirrors constants.dart but accepts String)
// ──────────────────────────────────────────────────────────────────────────────

/// Returns the brand colour for a severity level given as a raw string.
Color severityColorFromString(String severity) {
  final parsed = Severity.fromString(severity);
  return getSeverityColor(parsed);
}

// ──────────────────────────────────────────────────────────────────────────────
// Snackbar Helper
// ──────────────────────────────────────────────────────────────────────────────

/// Shows a themed [SnackBar] with the given [message].
///
/// [type] controls the background colour:
/// - `success`  → Teal
/// - `error`    → Red
/// - `warning`  → Amber
/// - `info`     → Primary surface (default)
void showAppSnackBar(
  BuildContext context,
  String message, {
  String type = 'info',
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
}) {
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;

  switch (type) {
    case 'success':
      backgroundColor = const Color(kSuccessTealHex);
      textColor = Colors.white;
      icon = Icons.check_circle_outline;
      break;
    case 'error':
      backgroundColor = const Color(kEmergencyRedHex);
      textColor = Colors.white;
      icon = Icons.error_outline;
      break;
    case 'warning':
      backgroundColor = const Color(kAccentAmberHex);
      textColor = Colors.black87;
      icon = Icons.warning_amber_rounded;
      break;
    default:
      backgroundColor = const Color(kCardBackgroundHex);
      textColor = Colors.white;
      icon = Icons.info_outline;
      break;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        action: action,
      ),
    );
}

/// Convenience wrapper — shows a **success** snackbar.
void showSuccessSnackBar(BuildContext context, String message) {
  showAppSnackBar(context, message, type: 'success');
}

/// Convenience wrapper — shows an **error** snackbar.
void showErrorSnackBar(BuildContext context, String message) {
  showAppSnackBar(context, message, type: 'error');
}

/// Convenience wrapper — shows a **warning** snackbar.
void showWarningSnackBar(BuildContext context, String message) {
  showAppSnackBar(context, message, type: 'warning');
}
