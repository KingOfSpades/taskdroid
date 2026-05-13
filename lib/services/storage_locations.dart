import 'package:path_provider/path_provider.dart';

class StorageLocation {
  final String label;
  final String path;
  final bool isDefault;

  const StorageLocation({
    required this.label,
    required this.path,
    this.isDefault = false,
  });
}

Future<List<StorageLocation>> getAvailableStorageLocations() async {
  final locations = <StorageLocation>[];

  final appDocs = await getApplicationDocumentsDirectory();
  locations.add(
    StorageLocation(
      label: 'App data directory (default)',
      path: appDocs.path,
      isDefault: true,
    ),
  );

  final externalDir = await getExternalStorageDirectory();
  if (externalDir != null) {
    locations.add(
      StorageLocation(label: 'App external storage', path: externalDir.path),
    );
  }

  return locations;
}
