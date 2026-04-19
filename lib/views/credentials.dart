import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taskdroid/providers/profile_state.dart';
import 'package:taskdroid/models/profile.dart';
import 'package:taskdroid/widgets/app_drawer.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class CredentialsPage extends StatefulWidget {
  const CredentialsPage({super.key});

  @override
  State<CredentialsPage> createState() => _CredentialsPageState();
}

class _CredentialsPageState extends State<CredentialsPage> {
  final _nameController = TextEditingController();
  final _uuidController = TextEditingController();
  final _secretController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isTesting = false;
  String? _testResult;
  bool _isEditing = false;
  String? _editingProfileId;
  ProfileState? _profileState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _profileState = context.read<ProfileState>();
      _profileState!.addListener(_onProfileStateChanged);
      _loadCurrentProfile();
    });
  }

  void _onProfileStateChanged() {
    if (!mounted) return;
    _loadCurrentProfile();
  }

  void _loadCurrentProfile() {
    final profileState = context.read<ProfileState>();
    final profile = profileState.currentProfile;

    if (profile != null && _editingProfileId != profile.id) {
      setState(() {
        _nameController.text = profile.name;
        _uuidController.text = profile.uuid;
        _secretController.text = profile.secret;
        _serverUrlController.text = profile.serverUrl;
        _editingProfileId = profile.id;
        _isEditing = true;
        _testResult = null;
      });
    } else if (profile == null && _isEditing) {
      _clearForm();
    }
  }

  void _clearForm() {
    setState(() {
      _nameController.clear();
      _uuidController.clear();
      _secretController.clear();
      _serverUrlController.clear();
      _editingProfileId = null;
      _isEditing = false;
      _testResult = null;
    });
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    final profileState = context.read<ProfileState>();
    final existingProfile = profileState.currentProfile;
    final profile = Profile(
      id: _editingProfileId ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      uuid: _uuidController.text.trim(),
      secret: _secretController.text.trim(),
      serverUrl: _serverUrlController.text.trim(),
      recurrenceLimit: existingProfile?.recurrenceLimit ?? 1,
    );

    if (_isEditing) {
      await profileState.updateProfile(profile);
    } else {
      await profileState.addProfile(profile);
      await profileState.setCurrentProfile(profile.id);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Profile updated' : 'Profile created'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _testServer() async {
    final serverUrl = _serverUrlController.text.trim();
    if (serverUrl.isEmpty) {
      setState(() => _testResult = 'Please enter a server URL first');
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final uri = Uri.parse(serverUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200 &&
          response.body.contains('TaskChampion sync server')) {
        setState(() => _testResult = 'Success: TaskChampion server verified');
      } else {
        setState(
          () => _testResult =
              'Error: Not a valid sync server (HTTP ${response.statusCode})',
        );
      }
    } catch (e) {
      setState(() => _testResult = 'Error: Connection failed');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _deleteCurrentProfile() async {
    if (_editingProfileId == null) return;

    final profileState = context.read<ProfileState>();
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: const Text(
          'This will remove the local profile and its associated task database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await profileState.deleteProfile(_editingProfileId!);
      if (mounted) _clearForm();
    }
  }

  @override
  void dispose() {
    _profileState?.removeListener(_onProfileStateChanged);
    _nameController.dispose();
    _uuidController.dispose();
    _secretController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profiles & Sync',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              onPressed: _deleteCurrentProfile,
              tooltip: 'Delete Profile',
            ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/credentials'),
      body: Consumer<ProfileState>(
        builder: (context, profileState, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'Active Profile'),
                  _buildGroupContainer(
                    context,
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      initialValue: profileState.currentProfileId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_pin_outlined),
                        hintText: 'Create New Profile',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Add New Profile...'),
                        ),
                        ...profileState.profiles.map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        ),
                      ],
                      onChanged: (id) async {
                        if (id == null) {
                          _clearForm();
                        } else {
                          await profileState.setCurrentProfile(id);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildSectionHeader(context, 'Profile Configuration'),
                  _buildGroupContainer(
                    context,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Profile Name',
                            prefixIcon: Icon(Icons.badge_outlined),
                            hintText: 'e.g., Work, Personal',
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _uuidController,
                          decoration: const InputDecoration(
                            labelText: 'Client UUID (Optional)',
                            prefixIcon: Icon(Icons.fingerprint),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _secretController,
                          decoration: const InputDecoration(
                            labelText: 'Encryption Secret (Optional)',
                            prefixIcon: Icon(Icons.key_outlined),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _serverUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Server URL (Optional)',
                            prefixIcon: Icon(Icons.dns_outlined),
                            hintText: 'https://sync.example.com',
                          ),
                          keyboardType: TextInputType.url,
                        ),

                        if (_testResult != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _testResult!.contains('Success')
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : colorScheme.errorContainer.withValues(
                                      alpha: 0.3,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _testResult!.contains('Success')
                                    ? Colors.green
                                    : colorScheme.error,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              _testResult!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _testResult!.contains('Success')
                                    ? Colors.green.shade800
                                    : colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isTesting ? null : _testServer,
                                icon: _isTesting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.network_check, size: 18),
                                label: const Text('Test Server'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isLoading ? null : _saveProfile,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined, size: 18),
                                label: Text(_isEditing ? 'Update' : 'Save'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildGroupContainer(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}
