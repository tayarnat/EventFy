import 'package:flutter/material.dart';
import '../widgets/common/error_notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  static NotificationService get instance => _instance;

  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  void showError(String message, {bool showInConsole = true}) {
    if (showInConsole) {
      debugPrint('ERROR: $message');
    }
    
    if (_context != null) {
      ErrorNotification.show(_context!, message);
    }
  }

  void showSuccess(String message, {bool showInConsole = true}) {
    if (showInConsole) {
      debugPrint('SUCCESS: $message');
    }
    
    if (_context != null) {
      ErrorNotification.showSuccess(_context!, message);
    }
  }

  void showWarning(String message, {bool showInConsole = true}) {
    if (showInConsole) {
      debugPrint('WARNING: $message');
    }
    
    if (_context != null) {
      ErrorNotification.showWarning(_context!, message);
    }
  }

  void showInfo(String message, {bool showInConsole = true}) {
    if (showInConsole) {
      debugPrint('INFO: $message');
    }
    
    if (_context != null) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void showLoading(String message, {bool showInConsole = true}) {
    if (showInConsole) {
      debugPrint('LOADING: $message');
    }
    
    if (_context != null) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey[700],
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void hideCurrentNotification() {
    if (_context != null) {
      ScaffoldMessenger.of(_context!).hideCurrentSnackBar();
    }
  }

  void clearContext() {
    _context = null;
  }
}