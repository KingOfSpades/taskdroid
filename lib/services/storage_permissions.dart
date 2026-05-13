import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class StoragePermissions {
  static Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.storage.isGranted) return true;
    return false;
  }

  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    // Android 11+: MANAGE_EXTERNAL_STORAGE; older: legacy storage
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    status = await Permission.storage.request();
    return status.isGranted;
  }

  static Future<bool> requestPermissionAfterFailure() async {
    if (!Platform.isAndroid) return true;
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    status = await Permission.storage.request();
    return status.isGranted;
  }
}
