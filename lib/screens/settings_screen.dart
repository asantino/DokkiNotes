import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/google_drive_service.dart';
import '../services/db_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSyncState();
  }

  Future<void> _loadSyncState() async {
    final signedIn = await GoogleDriveService().isSignedIn();
    DBService.db.setGoogleSyncEnabled(signedIn);
    if (mounted) setState(() => _isSyncEnabled = signedIn);
  }

  Future<void> _toggleSync(bool value) async {
    setState(() => _isLoading = true);

    if (value) {
      final success = await GoogleDriveService().signIn();
      if (success) {
        final uploaded = await GoogleDriveService().uploadNotes();
        if (mounted) {
          setState(() => _isSyncEnabled = uploaded);
        }
        DBService.db.setGoogleSyncEnabled(uploaded);
      } else {
        if (mounted) {
          setState(() => _isSyncEnabled = false);
        }
        DBService.db.setGoogleSyncEnabled(false);
      }
    } else {
      await GoogleDriveService().signOut();
      if (mounted) {
        setState(() => _isSyncEnabled = false);
      }
      DBService.db.setGoogleSyncEnabled(false);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: const Text('Синхронизация Google Drive'),
            subtitle: const Text('Автоматическое резервное копирование'),
            value: _isSyncEnabled,
            onChanged: _isLoading ? null : _toggleSync,
            secondary: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Выйти', style: TextStyle(color: Colors.red)),
            onTap: () async {
              // Сохраняем Navigator заранее, чтобы избежать async gap warning
              final navigator = Navigator.of(context);
              await AuthService.instance.signOut();

              if (mounted) {
                navigator.pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
