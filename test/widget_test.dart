import 'package:flutter_test/flutter_test.dart';
import 'package:taskdroid/models/profile.dart';
import 'package:taskdroid/models/filter_tab.dart';

void main() {
  group('Profile model', () {
    test('toJson and fromJson roundtrip', () {
      final profile = Profile(
        id: 'test-id',
        name: 'Work',
        uuid: 'abc-123',
        secret: 's3cret',
        serverUrl: 'https://sync.example.com',
        calendarSync: true,
      );

      final json = profile.toJson();
      final restored = Profile.fromJson(json);

      expect(restored.id, profile.id);
      expect(restored.name, profile.name);
      expect(restored.uuid, profile.uuid);
      expect(restored.secret, profile.secret);
      expect(restored.serverUrl, profile.serverUrl);
      expect(restored.calendarSync, profile.calendarSync);
    });

    test('copyWith updates fields', () {
      final profile = Profile(
        id: 'id',
        name: 'Original',
        uuid: 'uuid',
        secret: 'secret',
        serverUrl: 'url',
      );

      final updated = profile.copyWith(name: 'Updated', calendarSync: true);
      expect(updated.name, 'Updated');
      expect(updated.calendarSync, true);
      expect(updated.id, profile.id);
    });

    test('fromJson handles missing fields gracefully', () {
      final profile = Profile.fromJson({'id': 'x'});
      expect(profile.id, 'x');
      expect(profile.name, '');
      expect(profile.calendarSync, false);
    });
  });

  group('FilterTab model', () {
    test('toJson and fromJson roundtrip', () {
      final tab = FilterTab(
        id: 'tab-1',
        name: 'Urgent',
        searchQuery: 'important',
        selectedTags: {'urgent', 'work'},
        selectedProjects: {'project-a'},
      );

      final json = tab.toJson();
      final restored = FilterTab.fromJson(json);

      expect(restored.id, tab.id);
      expect(restored.name, tab.name);
      expect(restored.searchQuery, tab.searchQuery);
      expect(restored.selectedTags, tab.selectedTags);
      expect(restored.selectedProjects, tab.selectedProjects);
    });

    test('copyWith updates fields', () {
      final tab = FilterTab(id: '1', name: 'All');
      final updated = tab.copyWith(name: 'Renamed', searchQuery: 'test');
      expect(updated.name, 'Renamed');
      expect(updated.searchQuery, 'test');
      expect(updated.id, '1');
    });

    test('defaults are correct', () {
      final tab = FilterTab(id: '1', name: 'Test');
      expect(tab.searchQuery, '');
      expect(tab.selectedTags, isEmpty);
      expect(tab.selectedProjects, isEmpty);
    });
  });
}
