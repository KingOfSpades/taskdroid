import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:taskdroid/src/rust/api.dart';

class CalendarService {
  static const _channel = MethodChannel('org.taskdroid/calendar');

  Future<bool> checkPermissions() async {
    try {
      final bool result = await _channel.invokeMethod('checkPermissions');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to check permissions: ${e.message}");
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final bool result = await _channel.invokeMethod('requestPermissions');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to request permissions: ${e.message}");
      return false;
    }
  }

  Future<void> syncTask(TaskView task) async {
    // if task is deleted or completed, remove from calendar
    if (task.status == TaskStatus.deleted ||
        task.status == TaskStatus.completed) {
      await deleteTask(task.uuid);
      return;
    }

    // if no due date, remove from calendar
    if (task.due == null) {
      await deleteTask(task.uuid);
      return;
    }

    try {
      await _channel.invokeMethod('saveTask', _mapTaskToEvent(task));
    } on PlatformException catch (e) {
      debugPrint("Failed to save calendar event: ${e.message}");
    }
  }

  Future<void> deleteTask(String uuid) async {
    try {
      await _channel.invokeMethod('deleteTask', {'uuid': uuid});
    } on PlatformException catch (e) {
      debugPrint("Failed to delete calendar event: ${e.message}");
    }
  }

  Future<int> deleteAllEvents() async {
    try {
      final int count = await _channel.invokeMethod('deleteAllEvents');
      return count;
    } on PlatformException catch (e) {
      debugPrint("Failed to delete all events: ${e.message}");
      return 0;
    }
  }

  Future<String> batchSync(List<TaskView> tasks) async {
    final calendarTasks = tasks
        .where((t) {
          return t.status == TaskStatus.pending && t.due != null;
        })
        .map((t) => _mapTaskToEvent(t))
        .toList();

    try {
      final String result = await _channel.invokeMethod('batchSync', {
        'tasks': calendarTasks,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Batch sync failed: ${e.message}");
      return "Sync failed: ${e.message}";
    }
  }

  Map<String, dynamic> _mapTaskToEvent(TaskView task) {
    final dueDate = DateTime.parse(task.due!);
    final startMs = dueDate.millisecondsSinceEpoch;

    // check for 'duration' UDA (in minutes)
    int durationMinutes = 60; // default 1h
    try {
      final durationUda = task.udas.firstWhere(
        (u) => u.key == 'duration',
        orElse: () => const UdaPair(key: 'duration', value: ''),
      );

      if (durationUda.value.isNotEmpty) {
        final parsed = int.tryParse(durationUda.value);
        if (parsed != null && parsed > 0) {
          durationMinutes = parsed;
        }
      }
    } catch (_) {
      // ignore
    }

    final endMs = startMs + (durationMinutes * 60 * 1000);

    final buffer = StringBuffer();
    if (task.project != null) buffer.writeln("Project: ${task.project}");
    if (task.tags.isNotEmpty) buffer.writeln("Tags: ${task.tags.join(', ')}");
    buffer.writeln("Urgency: ${task.urgency.toStringAsFixed(2)}");

    return {
      'uuid': task.uuid,
      'title': task.description,
      'description': buffer.toString().trim(),
      'start': startMs,
      'end': endMs,
    };
  }
}
