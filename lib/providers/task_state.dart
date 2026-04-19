import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskdroid/models/filter_tab.dart';
import 'package:taskdroid/models/profile.dart';
import 'package:taskdroid/services/calendar_service.dart';
import 'package:taskdroid/src/rust/api.dart';
import 'package:taskdroid/src/rust/frb_generated.dart';
import 'package:uuid/uuid.dart';

enum TaskQueueView { ready, waiting, scheduled }

class TaskState extends ChangeNotifier {
  static const String _recurrenceLimitUdaKey = 'taskdroid.recurrence.limit';

  TaskManager? _taskManager;
  List<TaskView> _readyTasks = [];
  List<TaskView> _waitingTasks = [];
  List<TaskView> _scheduledTasks = [];
  final Map<String, TaskView> _taskByUuid = {};
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  String _searchQuery = '';
  Set<String> _selectedTags = {};
  Set<String> _selectedProjects = {};

  List<FilterTab> _filterTabs = [];
  String? _currentTabId;
  String? _currentProfileId;
  bool _isCalendarSyncEnabled = false;
  int _recurrenceLimit = 1;
  Timer? _saveTabTimer;
  Timer? _debounceFilterTimer;
  TaskQueueView _queueView = TaskQueueView.ready;

  final Set<String> _selectedTaskUuids = {};

  List<TaskView>? _cachedFilteredTasks;
  String? _lastFilterKey;

  TaskManager? get taskManager => _taskManager;
  List<TaskView> get pendingTasks => _readyTasks;
  List<TaskView> get waitingTasks => _waitingTasks;
  List<TaskView> get scheduledTasks => _scheduledTasks;
  TaskQueueView get queueView => _queueView;
  List<TaskView> get currentViewTasks => _sourceTasksForCurrentView();
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  Set<String> get selectedTags => _selectedTags;
  Set<String> get selectedProjects => _selectedProjects;
  List<FilterTab> get filterTabs => _filterTabs;
  String? get currentProfileId => _currentProfileId;
  Set<String> get selectedTaskUuids => _selectedTaskUuids;
  bool get isSelectionMode => _selectedTaskUuids.isNotEmpty;

  final CalendarService _calendarService = CalendarService();

  FilterTab? get currentTab {
    if (_currentTabId == null) return null;
    try {
      return _filterTabs.firstWhere((tab) => tab.id == _currentTabId);
    } catch (_) {
      return null;
    }
  }

  Set<String> get allTags {
    final tags = <String>{};
    for (final task in _sourceTasksForCurrentView()) {
      tags.addAll(task.tags);
    }
    return tags;
  }

  Set<String> get allProjects {
    final projects = <String>{};
    for (final task in _sourceTasksForCurrentView()) {
      if (task.project != null && task.project!.isNotEmpty) {
        projects.add(task.project!);
      }
    }
    return projects;
  }

  Future<void> loadProfile(Profile profile) async {
    if (_taskManager != null && _currentProfileId == profile.id) {
      if (_readyTasks.isEmpty && !_isLoading) {
        await refreshPendingTasks();
      }
      return;
    }

    if (_isLoading && _currentProfileId == profile.id) {
      return;
    }

    _isLoading = true;
    _error = null;
    _currentProfileId = profile.id;
    _isCalendarSyncEnabled = profile.calendarSync;
    _recurrenceLimit = profile.recurrenceLimit < 1
        ? 1
        : profile.recurrenceLimit;
    notifyListeners();

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dbDirPath = '${docsDir.path}/${profile.id}/';

      _taskManager = TaskManager();
      await _taskManager!.loadProfile(directoryPath: dbDirPath);

      await _loadFilterTabs(profile.id);

      // Fix: Reset loading guard BEFORE refreshing tasks, else it instantly aborts
      _isLoading = false;
      await refreshPendingTasks();
    } catch (e) {
      debugPrint('Failed to load profile: $e');
      _error = 'Unable to load profile database.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshPendingTasks() async {
    if (_taskManager == null) return;
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final filter = TaskFilter(
        status: null,
        project: null,
        tags: [],
        searchTerm: null,
        offset: BigInt.from(0),
        limit: BigInt.from(5000),
      );

      final result = await _taskManager!.listTasks(filter: filter);
      final now = DateTime.now().toUtc();
      final ready = <TaskView>[];
      final waiting = <TaskView>[];
      final scheduled = <TaskView>[];
      _taskByUuid.clear();

      for (final task in result.tasks) {
        if (task.status == TaskStatus.pending) {
          if (_isWaitingTask(task, now)) {
            waiting.add(task);
          } else if (_isScheduledForFuture(task, now)) {
            scheduled.add(task);
          } else {
            ready.add(task);
          }
          _taskByUuid[task.uuid] = task;
        }
      }

      ready.sort((a, b) => b.urgency.compareTo(a.urgency));
      waiting.sort((a, b) => b.urgency.compareTo(a.urgency));
      scheduled.sort((a, b) => b.urgency.compareTo(a.urgency));

      _readyTasks = ready;
      _waitingTasks = waiting;
      _scheduledTasks = scheduled;
      _cachedFilteredTasks = null;
      _error = null;
    } catch (e) {
      _error = 'Failed to sync with local database.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isWaitingTask(TaskView task, DateTime nowUtc) {
    if (task.isWaiting) {
      return true;
    }
    final wait = task.wait;
    if (wait == null || wait.isEmpty) {
      return false;
    }

    final parsed = DateTime.tryParse(wait);
    if (parsed == null) {
      return false;
    }

    return parsed.toUtc().isAfter(nowUtc);
  }

  bool _isScheduledForFuture(TaskView task, DateTime nowUtc) {
    final scheduled = task.scheduled;
    if (scheduled == null || scheduled.isEmpty) {
      return false;
    }
    final parsed = DateTime.tryParse(scheduled);
    if (parsed == null) {
      return false;
    }
    return parsed.toUtc().isAfter(nowUtc);
  }

  List<TaskView> get filteredTasks {
    final filterKey =
        '${_queueView.name}:$_searchQuery:${_selectedTags.join(',')}:${_selectedProjects.join(',')}';

    if (_cachedFilteredTasks != null && _lastFilterKey == filterKey) {
      return _cachedFilteredTasks!;
    }

    var filtered = _sourceTasksForCurrentView();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((task) {
        return task.description.toLowerCase().contains(query) ||
            (task.project?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_selectedTags.isNotEmpty) {
      filtered = filtered.where((task) {
        return _selectedTags.every((tag) => task.tags.contains(tag));
      }).toList();
    }

    if (_selectedProjects.isNotEmpty) {
      filtered = filtered.where((task) {
        return task.project != null && _selectedProjects.contains(task.project);
      }).toList();
    }

    _cachedFilteredTasks = filtered;
    _lastFilterKey = filterKey;
    return filtered;
  }

  void setQueueView(TaskQueueView view) {
    if (_queueView == view) return;
    _queueView = view;
    _cachedFilteredTasks = null;
    notifyListeners();
  }

  List<TaskView> _sourceTasksForCurrentView() {
    switch (_queueView) {
      case TaskQueueView.ready:
        return _readyTasks;
      case TaskQueueView.waiting:
        return _waitingTasks;
      case TaskQueueView.scheduled:
        return _scheduledTasks;
    }
  }

  TaskView? findTaskByUuid(String uuid) => _taskByUuid[uuid];

  List<TaskView> get dependencyCandidates => [
    ..._readyTasks,
    ..._waitingTasks,
    ..._scheduledTasks,
  ];

  Future<String?> createTask(CreateTaskParams params) async {
    if (_taskManager == null) return 'No profile loaded';
    try {
      final mergedUdas = _mergeRecurrenceLimitUda(
        params.udas,
        params.recurrence,
      );
      final uuid = await _taskManager!.addTask(
        params: CreateTaskParams(
          description: params.description,
          status: params.status,
          project: params.project,
          priority: params.priority,
          tags: params.tags,
          due: params.due,
          wait: params.wait,
          scheduled: params.scheduled,
          recurrence: params.recurrence,
          until: params.until,
          udas: mergedUdas,
        ),
      );
      await refreshPendingTasks();

      if (_isCalendarSyncEnabled) {
        final newTask = await _taskManager!.getTask(uuidStr: uuid);
        await _calendarService.syncTask(newTask);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> markTaskDone(String uuid) async {
    if (_taskManager == null) return 'No profile loaded';
    try {
      await _taskManager!.doneTasks(uuidStrs: [uuid]);
      if (_isCalendarSyncEnabled) await _calendarService.deleteTask(uuid);
      await refreshPendingTasks();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteTask(String uuid) async {
    if (_taskManager == null) return 'No profile loaded';
    try {
      await _taskManager!.deleteTasks(uuidStrs: [uuid]);
      if (_isCalendarSyncEnabled) await _calendarService.deleteTask(uuid);
      await refreshPendingTasks();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteTaskSingle(String uuid) async {
    if (_taskManager == null) return 'No profile loaded';
    try {
      await _taskManager!.deleteTaskSingle(uuidStr: uuid);
      if (_isCalendarSyncEnabled) await _calendarService.deleteTask(uuid);
      await refreshPendingTasks();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteTaskSeries(String uuid) async {
    if (_taskManager == null) return 'No profile loaded';
    try {
      await _taskManager!.deleteTaskSeries(uuidStr: uuid);
      if (_isCalendarSyncEnabled) await _calendarService.deleteTask(uuid);
      await refreshPendingTasks();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> markTaskDoneSingle(String uuid) async {
    if (_taskManager == null) return 'No profile loaded';
    try {
      await _taskManager!.doneTaskSingle(uuidStr: uuid);
      if (_isCalendarSyncEnabled) await _calendarService.deleteTask(uuid);
      await refreshPendingTasks();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> markTaskDoneSeries(String uuid) async {
    if (_taskManager == null) return 'No profile loaded';
    try {
      await _taskManager!.doneTaskSeries(uuidStr: uuid);
      if (_isCalendarSyncEnabled) await _calendarService.deleteTask(uuid);
      await refreshPendingTasks();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateTask(String uuid, UpdateTaskParams params) async {
    if (_taskManager == null) return 'No profile loaded';
    try {
      final mergedUdas = _mergeRecurrenceLimitUda(
        params.setUdas,
        params.recurrence,
      );
      await _taskManager!.updateTask(
        uuidStr: uuid,
        params: UpdateTaskParams(
          description: params.description,
          status: params.status,
          project: params.project,
          priority: params.priority,
          due: params.due,
          wait: params.wait,
          scheduled: params.scheduled,
          recurrence: params.recurrence,
          until: params.until,
          addTags: params.addTags,
          removeTags: params.removeTags,
          addAnnotation: params.addAnnotation,
          removeAnnotations: params.removeAnnotations,
          addDepends: params.addDepends,
          removeDepends: params.removeDepends,
          start: params.start,
          setUdas: mergedUdas,
        ),
      );
      await refreshPendingTasks();

      if (_isCalendarSyncEnabled) {
        final updated = await _taskManager!.getTask(uuidStr: uuid);
        await _calendarService.syncTask(updated);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> undo() async {
    if (_taskManager == null) return 'No profile loaded';
    try {
      final success = await _taskManager!.undo();
      if (success) {
        await refreshPendingTasks();
        return null;
      }
      return 'Nothing to undo';
    } catch (e) {
      return 'Undo failed';
    }
  }

  void toggleTaskSelection(String uuid) {
    if (_selectedTaskUuids.contains(uuid)) {
      _selectedTaskUuids.remove(uuid);
    } else {
      _selectedTaskUuids.add(uuid);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedTaskUuids.clear();
    notifyListeners();
  }

  Future<String?> bulkMarkDone() async {
    if (_taskManager == null) return null;
    final ids = _selectedTaskUuids.toList();
    if (ids.isEmpty) return null;

    try {
      await _taskManager!.doneTasks(uuidStrs: ids);
      if (_isCalendarSyncEnabled) {
        for (var id in ids) {
          _calendarService.deleteTask(id);
        }
      }
      clearSelection();
      await refreshPendingTasks();
      return null;
    } catch (e) {
      return 'Bulk operation failed';
    }
  }

  Future<String?> bulkDelete() async {
    if (_taskManager == null) return null;
    final ids = _selectedTaskUuids.toList();
    if (ids.isEmpty) return null;

    try {
      await _taskManager!.deleteTasks(uuidStrs: ids);
      if (_isCalendarSyncEnabled) {
        for (var id in ids) {
          _calendarService.deleteTask(id);
        }
      }
      clearSelection();
      await refreshPendingTasks();
      return null;
    } catch (e) {
      return 'Bulk delete failed';
    }
  }

  Future<void> _loadFilterTabs(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('filter_tabs_$profileId');

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> tabsJson = jsonDecode(jsonString);
        _filterTabs = tabsJson.map((j) => FilterTab.fromJson(j)).toList();
        _currentTabId = prefs.getString('current_tab_id_$profileId');

        final tab = currentTab;
        if (tab != null) {
          _searchQuery = tab.searchQuery;
          _selectedTags = Set.from(tab.selectedTags);
          _selectedProjects = Set.from(tab.selectedProjects);
        }
      } else {
        final defaultTab = FilterTab(id: const Uuid().v4(), name: 'All Tasks');
        _filterTabs = [defaultTab];
        _currentTabId = defaultTab.id;
        await _saveFilterTabs(profileId);
      }
      _cachedFilteredTasks = null;
    } catch (e) {
      debugPrint('Tab load error: $e');
    }
  }

  Future<void> _saveFilterTabs(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'filter_tabs_$profileId',
      jsonEncode(_filterTabs.map((t) => t.toJson()).toList()),
    );
    if (_currentTabId != null) {
      await prefs.setString('current_tab_id_$profileId', _currentTabId!);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _cachedFilteredTasks = null;
    _scheduleTabUpdate();
    notifyListeners();
  }

  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    _cachedFilteredTasks = null;
    _scheduleTabUpdate();
    notifyListeners();
  }

  void toggleProject(String project) {
    if (_selectedProjects.contains(project)) {
      _selectedProjects.remove(project);
    } else {
      _selectedProjects.add(project);
    }
    _cachedFilteredTasks = null;
    _scheduleTabUpdate();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedTags.clear();
    _selectedProjects.clear();
    _cachedFilteredTasks = null;
    _scheduleTabUpdate();
    notifyListeners();
  }

  Future<void> switchToTab(String tabId) async {
    _saveTabTimer?.cancel();
    await _persistCurrentTabSettings();

    _currentTabId = tabId;
    final tab = currentTab;
    if (tab != null) {
      _searchQuery = tab.searchQuery;
      _selectedTags = Set.from(tab.selectedTags);
      _selectedProjects = Set.from(tab.selectedProjects);
    }
    _cachedFilteredTasks = null;
    notifyListeners();
  }

  Future<void> addFilterTab(String name) async {
    final newTab = FilterTab(
      id: const Uuid().v4(),
      name: name,
      searchQuery: _searchQuery,
      selectedTags: Set.from(_selectedTags),
      selectedProjects: Set.from(_selectedProjects),
    );

    _filterTabs = [
      ..._filterTabs,
      newTab,
    ]; // immutable update fixes the assertion crash
    _currentTabId = newTab.id;
    if (_currentProfileId != null) await _saveFilterTabs(_currentProfileId!);
    notifyListeners();
  }

  Future<void> deleteFilterTab(String id) async {
    if (_filterTabs.length <= 1) return;

    _filterTabs = _filterTabs
        .where((t) => t.id != id)
        .toList(); // immutable update
    if (_currentTabId == id) await switchToTab(_filterTabs.first.id);
    if (_currentProfileId != null) await _saveFilterTabs(_currentProfileId!);
    notifyListeners();
  }

  Future<void> renameFilterTab(String id, String name) async {
    final idx = _filterTabs.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final newList = List<FilterTab>.from(_filterTabs);
      newList[idx] = newList[idx].copyWith(name: name);
      _filterTabs = newList; // immutable update
      if (_currentProfileId != null) await _saveFilterTabs(_currentProfileId!);
      notifyListeners();
    }
  }

  void _scheduleTabUpdate() {
    _saveTabTimer?.cancel();
    _saveTabTimer = Timer(
      const Duration(milliseconds: 500),
      () => _persistCurrentTabSettings(),
    );
  }

  Future<void> _persistCurrentTabSettings() async {
    if (_currentProfileId == null || _currentTabId == null) return;
    final idx = _filterTabs.indexWhere((t) => t.id == _currentTabId);
    if (idx != -1) {
      final newList = List<FilterTab>.from(_filterTabs);
      newList[idx] = newList[idx].copyWith(
        searchQuery: _searchQuery,
        selectedTags: _selectedTags,
        selectedProjects: _selectedProjects,
      );
      _filterTabs = newList; // immutable update
      await _saveFilterTabs(_currentProfileId!);
    }
  }

  String getTaskDescription(String uuid) {
    final task = _taskByUuid[uuid];
    if (task != null) {
      return task.description;
    }
    return 'Task (${uuid.substring(0, 8)})';
  }

  Future<int> getTotalTaskCount() async {
    if (_taskManager == null) return 0;
    try {
      final result = await _taskManager!.listTasks(
        filter: TaskFilter(
          status: null,
          tags: [],
          searchTerm: null,
          project: null,
          offset: BigInt.from(0),
          limit: BigInt.from(1),
        ),
      );
      return result.totalCount.toInt();
    } catch (_) {
      return _readyTasks.length + _waitingTasks.length;
    }
  }

  void clearProfile() {
    _taskManager = null;
    _readyTasks = [];
    _waitingTasks = [];
    _scheduledTasks = [];
    _taskByUuid.clear();
    _queueView = TaskQueueView.ready;
    _currentProfileId = null;
    _recurrenceLimit = 1;
    _currentTabId = null;
    notifyListeners();
  }

  List<UdaPair> _mergeRecurrenceLimitUda(
    List<UdaPair> source,
    String? recurrence,
  ) {
    final hasRecurrence = recurrence != null && recurrence.trim().isNotEmpty;
    final filtered = source
        .where((pair) => pair.key != _recurrenceLimitUdaKey)
        .toList(growable: true);
    if (hasRecurrence) {
      filtered.add(
        UdaPair(
          key: _recurrenceLimitUdaKey,
          value: _recurrenceLimit.toString(),
        ),
      );
    }
    return filtered;
  }

  @override
  void dispose() {
    _saveTabTimer?.cancel();
    _debounceFilterTimer?.cancel();
    super.dispose();
  }

  Future<String?> sync(Profile profile) async {
    _isSyncing = true;
    notifyListeners();
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dbDirPath = '${docsDir.path}/${profile.id}/';

      final result = await compute(
        _syncInIsolate,
        _SyncParams(
          directoryPath: dbDirPath,
          url: profile.serverUrl,
          clientId: profile.uuid,
          encryptionSecret: profile.secret,
        ),
      );

      if (!result.success) return result.error;

      await refreshPendingTasks();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<String?> exportData({required bool includeDeleted}) async {
    if (_taskManager == null) return null;
    return await _taskManager!.exportTasks(includeDeleted: includeDeleted);
  }

  Future<String?> importData(String jsonData) async {
    if (_taskManager == null) return "Profile not loaded";
    try {
      await _taskManager!.importTasks(jsonData: jsonData);
      await refreshPendingTasks();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

class _SyncParams {
  final String directoryPath;
  final String url;
  final String clientId;
  final String encryptionSecret;
  _SyncParams({
    required this.directoryPath,
    required this.url,
    required this.clientId,
    required this.encryptionSecret,
  });
}

class _SyncResult {
  final bool success;
  final String? error;
  _SyncResult({required this.success, this.error});
}

Future<_SyncResult> _syncInIsolate(_SyncParams params) async {
  try {
    await RustLib.init();
    final manager = TaskManager();
    await manager.loadProfile(directoryPath: params.directoryPath);
    await manager.sync_(
      url: params.url,
      clientId: params.clientId,
      encryptionSecret: params.encryptionSecret,
    );
    return _SyncResult(success: true);
  } catch (e) {
    return _SyncResult(success: false, error: e.toString());
  }
}
