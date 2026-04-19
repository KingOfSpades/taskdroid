import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taskdroid/providers/app_state.dart';
import 'package:taskdroid/providers/profile_state.dart';
import 'package:taskdroid/providers/task_state.dart';
import 'package:taskdroid/src/rust/api.dart';
import 'package:taskdroid/views/onboarding.dart';
import 'package:taskdroid/widgets/app_drawer.dart';
import 'package:taskdroid/widgets/filter_tabs.dart';
import 'package:taskdroid/widgets/task_list.dart';
import 'package:taskdroid/widgets/task_editor.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String? _lastProfileId;
  bool _hasAttemptedSyncOnStart = false;
  bool _hasInitializedProfile = false;
  bool _isSearchVisible = false;

  late final AnimationController _syncAnimController;

  @override
  void initState() {
    super.initState();
    _syncAnimController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  String _emptyStateSubtitle(TaskQueueView queueView) {
    switch (queueView) {
      case TaskQueueView.ready:
        return 'Add your next task to get started.';
      case TaskQueueView.waiting:
        return 'Tasks with future wait dates will appear here.';
      case TaskQueueView.scheduled:
        return 'Tasks scheduled for the future will appear here.';
    }
  }

  String _emptyStateButtonText(TaskQueueView queueView) {
    switch (queueView) {
      case TaskQueueView.ready:
        return 'Add task';
      case TaskQueueView.waiting:
        return 'Switch to Ready';
      case TaskQueueView.scheduled:
        return 'Switch to Ready';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitializedProfile) {
      _hasInitializedProfile = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _doInitialProfileLoad();
      });
    }
  }

  void _doInitialProfileLoad() {
    final profileState = context.read<ProfileState>();
    final taskState = context.read<TaskState>();
    final appState = context.read<AppState>();

    if (profileState.currentProfile != null) {
      taskState.loadProfile(profileState.currentProfile!);
      _lastProfileId = profileState.currentProfileId;
      _hasAttemptedSyncOnStart = false;
      _handleSyncOnStart(context, appState, profileState, taskState);
    }
  }

  @override
  void dispose() {
    _syncAnimController.dispose();
    super.dispose();
  }

  void _handleSyncOnStart(
    BuildContext context,
    AppState appState,
    ProfileState profileState,
    TaskState taskState,
  ) {
    if (_hasAttemptedSyncOnStart) return;
    if (!appState.syncOnStart) return;

    final profile = profileState.currentProfile;
    if (profile == null || profile.serverUrl.isEmpty) return;
    if (taskState.currentProfileId != profile.id) return;

    _hasAttemptedSyncOnStart = true;

    taskState.sync(profile).then((error) {
      if (!context.mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-sync failed: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-synced successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskState = context.watch<TaskState>();
    final profileState = context.watch<ProfileState>();
    final appState = context.watch<AppState>();

    if (profileState.currentProfileId != _lastProfileId) {
      _lastProfileId = profileState.currentProfileId;
      _hasAttemptedSyncOnStart = false;
      if (profileState.currentProfile != null) {
        final profile = profileState.currentProfile!;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            taskState.loadProfile(profile);
            _handleSyncOnStart(context, appState, profileState, taskState);
          }
        });
      }
    }

    // anim control for sync icon
    if (taskState.isSyncing) {
      if (!_syncAnimController.isAnimating) _syncAnimController.repeat();
    } else {
      if (_syncAnimController.isAnimating) _syncAnimController.reset();
    }

    // check for onboarding
    if (profileState.isLoaded && profileState.profiles.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(child: OnboardingPage(onComplete: () {})),
      );
    }

    // standard app layout
    return Scaffold(
      drawer: const AppDrawer(currentRoute: '/'),
      appBar: taskState.isSelectionMode
          ? _buildSelectionBar(context, taskState)
          : _buildTopBar(context, taskState),
      floatingActionButton: taskState.isSelectionMode
          ? null
          : FloatingActionButton.extended(
              elevation: 2,
              onPressed: () => _showCreateSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('New Task'),
            ),
      body: _buildMainBody(context, profileState, taskState),
    );
  }

  Widget _buildMainBody(
    BuildContext context,
    ProfileState profileState,
    TaskState taskState,
  ) {
    if (profileState.currentProfile == null) {
      return const _NoProfileState();
    }

    return Column(
      children: [
        if (taskState.isSyncing) const LinearProgressIndicator(minHeight: 2),
        const FilterTabsRow(),
        _QueueViewAndSearchToggleRow(
          selected: taskState.queueView,
          readyCount: taskState.pendingTasks.length,
          waitingCount: taskState.waitingTasks.length,
          scheduledCount: taskState.scheduledTasks.length,
          onSelected: taskState.setQueueView,
          isSearchVisible: _isSearchVisible,
          onToggleSearch: () {
            setState(() {
              _isSearchVisible = !_isSearchVisible;
            });
          },
          filterCount:
              taskState.selectedTags.length + taskState.selectedProjects.length,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _isSearchVisible
              ? _SearchAndFiltersRow(
                  searchQuery: taskState.searchQuery,
                  onSearchChanged: taskState.setSearchQuery,
                  selectedTags: taskState.selectedTags,
                  selectedProjects: taskState.selectedProjects,
                  onOpenTags: () => _showTagSelector(context, taskState),
                  onOpenProjects: () =>
                      _showProjectSelector(context, taskState),
                  onClear: taskState.clearFilters,
                  onRemoveTag: taskState.toggleTag,
                  onRemoveProject: taskState.toggleProject,
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
        Expanded(child: _buildTaskBody(context, taskState)),
      ],
    );
  }

  PreferredSizeWidget _buildTopBar(BuildContext context, TaskState taskState) {
    final profileState = context.watch<ProfileState>();
    final currentProfile = profileState.currentProfile;
    final initials = (currentProfile?.name.isNotEmpty ?? false)
        ? currentProfile!.name[0].toUpperCase()
        : 'T';

    return AppBar(
      title: const Text('Tasks', style: TextStyle(fontWeight: FontWeight.w600)),
      leading: Builder(
        builder: (context) {
          return IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        },
      ),
      actions: [
        if (currentProfile?.serverUrl.isNotEmpty ?? false)
          IconButton(
            onPressed: taskState.isSyncing
                ? null
                : () async {
                    final error = await taskState.sync(currentProfile!);
                    if (!context.mounted) return;
                    final theme = Theme.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error ?? 'Sync complete'),
                        backgroundColor: error == null
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.error,
                      ),
                    );
                  },
            icon: RotationTransition(
              turns: _syncAnimController,
              child: const Icon(Icons.sync),
            ),
            tooltip: taskState.isSyncing ? 'Syncing...' : 'Sync',
          ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => _showProfileSwitcher(context),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionBar(
    BuildContext context,
    TaskState taskState,
  ) {
    final count = taskState.selectedTaskUuids.length;
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: taskState.clearSelection,
      ),
      title: Text(
        '$count selected',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.check_circle_outline),
          tooltip: 'Mark Done',
          onPressed: () async {
            final error = await taskState.bulkMarkDone();
            if (!context.mounted) return;
            _showUndoSnack(
              context,
              error ?? '$count tasks completed',
              isError: error != null,
              onUndo: error == null ? taskState.undo : null,
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: () async {
            final error = await taskState.bulkDelete();
            if (!context.mounted) return;
            _showUndoSnack(
              context,
              error ?? '$count tasks deleted',
              isError: error != null,
              onUndo: error == null ? taskState.undo : null,
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTaskBody(BuildContext context, TaskState taskState) {
    if (taskState.error != null && taskState.currentViewTasks.isEmpty) {
      return _InlineMessageState(
        icon: Icons.error_outline,
        title: 'Unable to load tasks',
        subtitle: taskState.error!,
        buttonText: 'Retry',
        onPressed: taskState.refreshPendingTasks,
      );
    }

    if (taskState.isLoading && taskState.currentViewTasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (taskState.currentViewTasks.isEmpty) {
      return _InlineMessageState(
        icon: Icons.task_alt,
        title: 'You\'re all caught up!',
        subtitle: _emptyStateSubtitle(taskState.queueView),
        buttonText: _emptyStateButtonText(taskState.queueView),
        onPressed: () {
          if (taskState.queueView == TaskQueueView.ready) {
            _showCreateSheet(context);
          } else {
            taskState.setQueueView(TaskQueueView.ready);
          }
        },
      );
    }

    if (taskState.filteredTasks.isEmpty) {
      return _InlineMessageState(
        icon: Icons.search_off,
        title: 'No matches found',
        subtitle: 'Try adjusting your filters or search query.',
        buttonText: 'Clear filters',
        onPressed: () {
          taskState.clearFilters();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: taskState.refreshPendingTasks,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TaskListItem(task: taskState.filteredTasks[index]),
              ),
              childCount: taskState.filteredTasks.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final taskState = context.read<TaskState>();
    if (taskState.currentProfileId == null) return;

    final result = await showTaskEditorSheet(context);
    if (!context.mounted || result == null) return;

    final udaMap = {for (final uda in result.udas) uda.key: uda.value};
    final recurrence = result.recurrence ?? '';

    final error = await taskState.createTask(
      CreateTaskParams(
        description: result.description,
        status: TaskStatus.pending,
        project: result.project,
        priority: result.priority,
        tags: result.tags,
        due: result.due?.toUtc().toIso8601String(),
        wait: result.wait?.toUtc().toIso8601String(),
        scheduled: result.scheduled?.toUtc().toIso8601String(),
        until: result.until?.toUtc().toIso8601String(),
        recurrence: recurrence.isEmpty ? null : recurrence,
        udas: udaMap.entries
            .map((entry) => UdaPair(key: entry.key, value: entry.value))
            .toList(),
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Task created')));
  }

  void _showUndoSnack(
    BuildContext context,
    String message, {
    required bool isError,
    Future<String?> Function()? onUndo,
  }) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? theme.colorScheme.error
            : theme.colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
        action: onUndo == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                textColor: isError
                    ? theme.colorScheme.onError
                    : theme.colorScheme.onPrimaryContainer,
                onPressed: () => onUndo(),
              ),
      ),
    );
  }

  Future<void> _showProfileSwitcher(BuildContext context) async {
    final profileState = context.read<ProfileState>();
    final theme = Theme.of(context);

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Switch Profile',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: profileState.profiles.map((profile) {
                    final isSelected =
                        profileState.currentProfileId == profile.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        foregroundColor: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                        child: Text(profile.name[0].toUpperCase()),
                      ),
                      title: Text(
                        profile.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      onTap: () => Navigator.pop(context, profile.id),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await profileState.setCurrentProfile(selected);
    }
  }

  Future<void> _showTagSelector(
    BuildContext context,
    TaskState taskState,
  ) async {
    final local = Set<String>.from(taskState.selectedTags);
    await _showFilterSheet(
      context,
      'Filter by Tags',
      taskState.allTags,
      local,
      (updated) {
        final toAdd = updated.difference(taskState.selectedTags);
        final toRemove = taskState.selectedTags.difference(updated);
        for (final tag in toAdd) {
          taskState.toggleTag(tag);
        }
        for (final tag in toRemove) {
          taskState.toggleTag(tag);
        }
      },
    );
  }

  Future<void> _showProjectSelector(
    BuildContext context,
    TaskState taskState,
  ) async {
    final local = Set<String>.from(taskState.selectedProjects);
    await _showFilterSheet(
      context,
      'Filter by Projects',
      taskState.allProjects,
      local,
      (updated) {
        final toAdd = updated.difference(taskState.selectedProjects);
        final toRemove = taskState.selectedProjects.difference(updated);
        for (final project in toAdd) {
          taskState.toggleProject(project);
        }
        for (final project in toRemove) {
          taskState.toggleProject(project);
        }
      },
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    String title,
    Set<String> allItems,
    Set<String> localSelections,
    Function(Set<String>) onApply,
  ) async {
    final theme = Theme.of(context);
    final applied = await showModalBottomSheet<Set<String>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (allItems.isEmpty)
                      const Text('No items available')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allItems
                            .map(
                              (item) => FilterChip(
                                label: Text(item),
                                selected: localSelections.contains(item),
                                onSelected: (_) {
                                  setModalState(() {
                                    if (localSelections.contains(item)) {
                                      localSelections.remove(item);
                                    } else {
                                      localSelections.add(item);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setModalState(localSelections.clear),
                          child: const Text('Clear All'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, localSelections),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (applied != null) onApply(applied);
  }
}

class _SearchAndFiltersRow extends StatefulWidget {
  const _SearchAndFiltersRow({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedTags,
    required this.selectedProjects,
    required this.onOpenTags,
    required this.onOpenProjects,
    required this.onClear,
    required this.onRemoveTag,
    required this.onRemoveProject,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final Set<String> selectedTags;
  final Set<String> selectedProjects;
  final VoidCallback onOpenTags;
  final VoidCallback onOpenProjects;
  final VoidCallback onClear;
  final ValueChanged<String> onRemoveTag;
  final ValueChanged<String> onRemoveProject;

  @override
  State<_SearchAndFiltersRow> createState() => _SearchAndFiltersRowState();
}

class _SearchAndFiltersRowState extends State<_SearchAndFiltersRow> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _SearchAndFiltersRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _searchController.text) {
      _searchController.value = _searchController.value.copyWith(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        widget.selectedTags.isNotEmpty || widget.selectedProjects.isNotEmpty;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: widget.onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search tasks...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearchChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.label_outline, size: 16),
                label: Text(
                  widget.selectedTags.isEmpty
                      ? 'Tags'
                      : 'Tags (${widget.selectedTags.length})',
                ),
                onPressed: widget.onOpenTags,
                backgroundColor: widget.selectedTags.isNotEmpty
                    ? theme.colorScheme.primaryContainer
                    : null,
                side: BorderSide(
                  color: widget.selectedTags.isNotEmpty
                      ? Colors.transparent
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.folder_outlined, size: 16),
                label: Text(
                  widget.selectedProjects.isEmpty
                      ? 'Projects'
                      : 'Projects (${widget.selectedProjects.length})',
                ),
                onPressed: widget.onOpenProjects,
                backgroundColor: widget.selectedProjects.isNotEmpty
                    ? theme.colorScheme.primaryContainer
                    : null,
                side: BorderSide(
                  color: widget.selectedProjects.isNotEmpty
                      ? Colors.transparent
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              if (hasFilters || _searchController.text.isNotEmpty) ...[
                const Spacer(),
                TextButton(
                  onPressed: widget.onClear,
                  child: const Text('Clear'),
                ),
              ],
            ],
          ),
          if (hasFilters) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...widget.selectedTags.map(
                    (tag) => InputChip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      onDeleted: () => widget.onRemoveTag(tag),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  ...widget.selectedProjects.map(
                    (project) => InputChip(
                      avatar: const Icon(Icons.folder_outlined, size: 14),
                      label: Text(
                        project,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () => widget.onRemoveProject(project),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QueueViewAndSearchToggleRow extends StatelessWidget {
  const _QueueViewAndSearchToggleRow({
    required this.selected,
    required this.readyCount,
    required this.waitingCount,
    required this.scheduledCount,
    required this.onSelected,
    required this.isSearchVisible,
    required this.onToggleSearch,
    required this.filterCount,
  });

  final TaskQueueView selected;
  final int readyCount;
  final int waitingCount;
  final int scheduledCount;
  final ValueChanged<TaskQueueView> onSelected;
  final bool isSearchVisible;
  final VoidCallback onToggleSearch;
  final int filterCount;

  String _formatCount(int count) {
    if (count < 1000) return '$count';
    if (count < 1000000) {
      final value = count / 1000;
      final text = value >= 100
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
      return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}k';
    }
    final value = count / 1000000;
    final text = value >= 100
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}M';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget chip(TaskQueueView view, String label, int count, IconData icon) {
      final active = selected == view;
      return ChoiceChip(
        avatar: Icon(icon, size: 16),
        label: Text('$label (${_formatCount(count)})'),
        selected: active,
        onSelected: (_) => onSelected(view),
        showCheckmark: false,
        side: BorderSide(
          color: active
              ? Colors.transparent
              : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip(
                    TaskQueueView.ready,
                    'Ready',
                    readyCount,
                    Icons.task_alt,
                  ),
                  const SizedBox(width: 8),
                  chip(
                    TaskQueueView.waiting,
                    'Waiting',
                    waitingCount,
                    Icons.hourglass_empty,
                  ),
                  const SizedBox(width: 8),
                  chip(
                    TaskQueueView.scheduled,
                    'Scheduled',
                    scheduledCount,
                    Icons.schedule,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onToggleSearch,
            icon: Stack(
              children: [
                Icon(isSearchVisible ? Icons.search_off : Icons.search),
                if (filterCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        filterCount > 9 ? '9+' : '$filterCount',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            color: isSearchVisible || filterCount > 0
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            tooltip: 'Toggle Search & Filters',
          ),
        ],
      ),
    );
  }
}

class _NoProfileState extends StatelessWidget {
  const _NoProfileState();

  @override
  Widget build(BuildContext context) {
    return _InlineMessageState(
      icon: Icons.account_circle_outlined,
      title: 'No profile selected',
      subtitle: 'Select or create a profile to start managing tasks.',
      buttonText: 'Open Menu',
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
}

class _InlineMessageState extends StatelessWidget {
  const _InlineMessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.tonal(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
