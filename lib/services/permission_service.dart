import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Check and request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    // Check current status
    var status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    }

    // Request permission
    if (status.isDenied) {
      status = await Permission.microphone.request();
      return status.isGranted;
    }

    // If permission is permanently denied, open app settings
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      // We can't know if the user granted permission in settings
      // so we check again
      return await Permission.microphone.status.isGranted;
    }

    return false;
  }

  // Check if microphone permission is granted
  static Future<bool> isMicrophonePermissionGranted() async {
    return await Permission.microphone.isGranted;
  }

  // Check if storage permission is granted (for saving samples)
  static Future<bool> requestStoragePermission() async {
    var status = await Permission.storage.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      status = await Permission.storage.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return await Permission.storage.status.isGranted;
    }

    return false;
  }
}
