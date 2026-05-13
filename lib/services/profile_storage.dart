import 'dart:io';

import 'package:file_selector/file_selector.dart' show getDirectoryPath;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskdroid/models/profile.dart';

const _keyGlobalStoragePath = 'global_storage_path';

Future<String> getGlobalStoragePath() async {
  final prefs = await SharedPreferences.getInstance();
  final customPath = prefs.getString(_keyGlobalStoragePath);
  if (customPath != null && customPath.trim().isNotEmpty) {
    return customPath.trim();
  }
  final docsDir = await getApplicationDocumentsDirectory();
  return docsDir.path;
}

Future<void> setGlobalStoragePath(String? path) async {
  final prefs = await SharedPreferences.getInstance();
  if (path == null || path.trim().isEmpty) {
    await prefs.remove(_keyGlobalStoragePath);
  } else {
    await prefs.setString(_keyGlobalStoragePath, path.trim());
  }
}

String sanitizeProfileName(String name) {
  String s = name.trim();
  if (s.isEmpty) return 'unnamed';
  s = s.replaceAll(RegExp(r'[/\\:\0<>"|?*]'), '_');
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  s = s.replaceAll(RegExp(r'_+'), '_');
  if (s.length > 100) s = s.substring(0, 100);
  return s.trim();
}

Future<Directory> resolveProfileStorageDir(Profile profile) async {
  final basePath = await getGlobalStoragePath();
  final dirName = sanitizeProfileName(profile.name);
  final profileDir = Directory('$basePath/$dirName/');

  // legacy migration: rename old ID-based directory to name-based
  final oldDir = Directory('$basePath/${profile.id}/');
  if (await oldDir.exists() && !await profileDir.exists()) {
    if (!await _moveDirectory(oldDir, profileDir)) {
      debugPrint('Legacy directory migration failed for ${profile.id}');
    }
  }

  return profileDir;
}

Future<bool> renameProfileDirectory(
  Profile oldProfile,
  Profile newProfile,
) async {
  if (oldProfile.name == newProfile.name) return true;

  final basePath = await getGlobalStoragePath();
  final oldName = sanitizeProfileName(oldProfile.name);
  final newName = sanitizeProfileName(newProfile.name);
  if (oldName == newName) return true;

  final oldDir = Directory('$basePath/$oldName/');
  final newDir = Directory('$basePath/$newName/');

  if (!await oldDir.exists()) return true;
  if (await newDir.exists()) return false;

  if (!await _moveDirectory(oldDir, newDir)) {
    debugPrint('Failed to rename directory for ${newProfile.id}');
    return false;
  }
  return true;
}

/// convert an Android SAF content URI to a real filesystem path
/// supports `content://com.android.externalstorage.documents/tree/primary%3A<path>`
String? safUriToRealPath(String uri) {
  const prefix = 'content://com.android.externalstorage.documents/tree/';
  if (!uri.startsWith(prefix)) return null;

  final decoded = Uri.decodeComponent(uri.substring(prefix.length));
  if (!decoded.startsWith('primary')) return null;

  var relative = decoded.substring('primary'.length);
  if (relative.startsWith(':')) relative = relative.substring(1);

  return '/storage/emulated/0/$relative';
}

Future<String> getDefaultStoragePath() async {
  final docsDir = await getApplicationDocumentsDirectory();
  return docsDir.path;
}

/// one-time migration: rename every legacy ID-based profile folder to its
/// name-based equivalent within the current storage path
Future<void> migrateLegacyProfileDirectories(List<Profile> profiles) async {
  final basePath = await getGlobalStoragePath();
  for (final profile in profiles) {
    final dirName = sanitizeProfileName(profile.name);
    final newDir = Directory('$basePath/$dirName/');
    final oldDir = Directory('$basePath/${profile.id}/');
    if (!await oldDir.exists() || await newDir.exists()) continue;
    if (!await _moveDirectory(oldDir, newDir)) {
      debugPrint('Legacy migration failed for ${profile.id}');
    }
  }
}

/// migrate all profile data from [oldPath] to [newPath] by name
/// returns profiles that failed to migrate
Future<List<Profile>> migrateProfilesToNewPath({
  required String oldPath,
  required String newPath,
  required List<Profile> profiles,
  bool deleteSource = true,
}) async {
  if (oldPath == newPath) return [];

  final failures = <Profile>[];

  for (final profile in profiles) {
    final dirName = sanitizeProfileName(profile.name);
    final newDir = Directory('$newPath/$dirName/');

    Directory? sourceDir;
    final nameDir = Directory('$oldPath/$dirName/');
    if (await nameDir.exists()) {
      sourceDir = nameDir;
    } else {
      final legacyDir = Directory('$oldPath/${profile.id}/');
      if (await legacyDir.exists()) sourceDir = legacyDir;
    }

    if (sourceDir == null) continue;

    if (await newDir.exists()) {
      failures.add(profile);
      continue;
    }

    var success = true;
    if (deleteSource) {
      try {
        await sourceDir.rename(newDir.path);
      } catch (_) {
        try {
          await _copyIntoTaskDbDir(sourceDir, newDir);
          await sourceDir.delete(recursive: true);
        } catch (e) {
          debugPrint('Failed to migrate profile ${profile.id}: $e');
          success = false;
        }
      }
    } else {
      try {
        await _copyIntoTaskDbDir(sourceDir, newDir);
      } catch (e) {
        debugPrint('Failed to copy profile ${profile.id}: $e');
        success = false;
      }
    }

    if (!success) failures.add(profile);
  }

  return failures;
}

/// copy [source] contents into [profileDest]/taskdb/
Future<void> _copyIntoTaskDbDir(Directory source, Directory profileDest) async {
  final taskDbDest = Directory('${profileDest.path}/taskdb/');
  await taskDbDest.create(recursive: true);
  await for (final entity in source.list()) {
    final name = entity.uri.pathSegments.last;
    if (name == 'taskdb' && entity is Directory) {
      await _copyDirectory(entity, taskDbDest);
    } else if (entity is File) {
      await entity.copy('${taskDbDest.path}/$name');
    } else if (entity is Directory) {
      await _copyDirectory(entity, Directory('${taskDbDest.path}/$name'));
    }
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final entity in source.list()) {
    if (entity is File) {
      final name = entity.uri.pathSegments.last;
      await entity.copy('${destination.path}/$name');
    } else if (entity is Directory) {
      final name = entity.uri.pathSegments.last;
      await _copyDirectory(entity, Directory('${destination.path}/$name'));
    }
  }
}

Future<bool> _moveDirectory(Directory source, Directory destination) async {
  try {
    await source.rename(destination.path);
    return true;
  } catch (_) {
    try {
      await _copyDirectory(source, destination);
      await source.delete(recursive: true);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// opens the system folder picker (SAF) and returns a real filesystem path
Future<String?> pickStorageDirectory() async {
  final picked = await getDirectoryPath();
  if (picked == null || picked.trim().isEmpty) return null;

  final trimmed = picked.trim();

  if (trimmed.startsWith('content://')) {
    final realPath = safUriToRealPath(trimmed);
    if (realPath != null) return realPath;

    if (Directory(trimmed).existsSync()) return trimmed;

    return null;
  }

  return trimmed;
}
