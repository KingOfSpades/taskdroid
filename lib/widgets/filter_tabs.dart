import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taskdroid/models/filter_tab.dart';
import 'package:taskdroid/providers/task_state.dart';

class FilterTabsRow extends StatelessWidget {
  const FilterTabsRow({super.key});

  @override
  Widget build(BuildContext context) {
    // rebuild when filterTabs or currentTab changes
    return Selector<TaskState, (List<FilterTab>, String?)>(
      selector: (_, state) => (state.filterTabs, state.currentTab?.id),
      builder: (context, data, _) {
        final (tabs, currentTabId) = data;

        final taskState = context.read<TaskState>();

        if (tabs.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: tabs.length + 1,
            itemBuilder: (context, index) {
              if (index == tabs.length) {
                return _AddTabChip(
                  key: const ValueKey('add-new-tab-chip'),
                  onNewTabCreated: (name) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      taskState.addFilterTab(name);
                    });
                  },
                );
              }

              final tab = tabs[index];
              final isActive = tab.id == currentTabId;

              return _TabChip(
                key: ValueKey(tab.id),
                tab: tab,
                isActive: isActive,
                taskState: taskState,
              );
            },
          ),
        );
      },
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    super.key,
    required this.tab,
    required this.isActive,
    required this.taskState,
  });

  final FilterTab tab;
  final bool isActive;
  final TaskState taskState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: colorScheme.primary.withValues(alpha: 0.2),
          onTap: () => taskState.switchToTab(tab.id),
          onLongPress: () => _showTabMenu(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isActive
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: Border.all(
                color: isActive
                    ? Colors.transparent
                    : colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tab.name,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTabMenu(BuildContext context) {
    final parentContext = context;
    final theme = Theme.of(context);
    final canDelete = taskState.filterTabs.length > 1;

    showModalBottomSheet<void>(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Tab Options',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(
                  Icons.edit_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text(
                  'Rename tab',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(parentContext);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(
                  Icons.delete_outline,
                  color: canDelete ? theme.colorScheme.error : null,
                ),
                title: Text(
                  canDelete ? 'Delete tab' : 'Cannot delete last tab',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: canDelete ? theme.colorScheme.error : null,
                  ),
                ),
                onTap: canDelete
                    ? () {
                        Navigator.pop(context);
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          await taskState.deleteFilterTab(tab.id);
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final controller = TextEditingController(text: tab.name);
    final theme = Theme.of(context);

    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Rename tab',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Tab name',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (val) {
              Navigator.pop(context, val.trim().isEmpty ? null : val.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                Navigator.pop(context, name.isEmpty ? null : name);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (newName != null && newName != tab.name) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await taskState.renameFilterTab(tab.id, newName);
      });
    }
  }
}

class _AddTabChip extends StatelessWidget {
  const _AddTabChip({super.key, required this.onNewTabCreated});

  final ValueChanged<String> onNewTabCreated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        avatar: Icon(
          Icons.add,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        label: const Text('New', style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        onPressed: () => _showAddDialog(context),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Create Filter Tab',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Work, Errands...',
              prefixIcon: Icon(Icons.tab_unselected),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (val) {
              Navigator.pop(context, val.trim().isEmpty ? null : val.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.pop(context, value.isEmpty ? null : value);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name != null && name.isNotEmpty) {
      onNewTabCreated(name);
    }
  }
}
