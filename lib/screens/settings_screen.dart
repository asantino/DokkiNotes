import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as path_helper;
import 'package:sqflite/sqflite.dart';
import '../services/prefs_service.dart';
import '../services/security_service.dart';
import '../services/db_service.dart';
import '../services/pin_service.dart';
import '../services/sync_status_service.dart';
import '../services/encryption_service.dart';
import '../services/auth_service.dart';
import '../services/railway_service.dart';
import '../theme/dokki_theme.dart';
import '../widgets/pin_input_dialog.dart';
import '../widgets/ai_mic_icon.dart';
import 'trash_screen.dart';
import 'auth_screen.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkMode;
  bool _isBiometricEnabled = false;
  int _trashCount = 0;
  bool _isSyncEnabled = false;
  int _balance = 0;

  @override
  void initState() {
    super.initState();
    _isDarkMode = prefs.isDarkMode;
    _initState();
  }

  Future<void> _initState() async {
    await _checkAuth();
    _loadBiometric();
    _loadTrashCount();
    _loadSyncState();
    _loadBalance();
  }

  Future<void> _checkAuth() async {
    final valid = await AuthService.instance.refreshSession();
    if (!valid && mounted) setState(() {});
  }

  Future<void> _loadBalance() async {
    if (AuthService.instance.isAuthenticated) {
      final balance = await RailwayService.instance.checkBalance();
      if (mounted) {
        setState(() {
          _balance = balance;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _balance = 0;
        });
      }
    }
  }

  Future<void> _loadBiometric() async {
    final available = await SecurityService().canCheckBiometrics();
    if (!available) {
      if (mounted) setState(() => _isBiometricEnabled = false);
      return;
    }
    final enabled = prefs.isBiometricEnabled;
    if (mounted) setState(() => _isBiometricEnabled = enabled);
  }

  Future<void> _loadSyncState() async {
    final hasPin = await pinService.hasPin();
    if (mounted) {
      setState(() {
        _isSyncEnabled = hasPin;
      });
    }
  }

  Future<void> _toggleSync(bool value) async {
    if (!mounted) return;

    if (value) {
      final pin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const PinInputDialog(
          title: 'Create PIN (4-8 digits)',
          isConfirmation: true,
        ),
      );

      if (pin != null && pin.length >= 4) {
        await pinService.setPin(pin);

        // --- Изменение 1 ---
        encryptionService.init(pin);
        DBService.db.setEncryptionKey(pin);
        // -------------------

        syncStatusService.updateStatus(SyncStatus.uploading);
        final vaultPath = await DBService.db.exportEncryptedDatabase(pin);

        if (vaultPath != null) {
          syncStatusService.updateStatus(SyncStatus.synced);
          if (mounted) setState(() => _isSyncEnabled = true);
        } else {
          syncStatusService.updateStatus(SyncStatus.error);
          await pinService.deletePin();

          // --- Изменение 2 ---
          DBService.db.setEncryptionKey(null);
          // -------------------

          if (mounted) {
            await _showErrorDialog();
            syncStatusService.updateStatus(SyncStatus.disabled);
          }
        }
      }
    } else {
      final confirmed = await _showDisableSyncConfirm();
      if (confirmed == true) {
        if (!mounted) return;
        final pin = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => const PinInputDialog(
            title: 'Enter PIN for decryption',
            isConfirmation: false,
          ),
        );

        if (pin != null) {
          final isValid = await pinService.verifyPin(pin);
          if (!isValid) {
            if (mounted) await _showErrorDialog();
            return;
          }

          // --- Изменение 3 ---
          DBService.db.setEncryptionKey(null);
          encryptionService.clearKey();
          // -------------------

          await _decryptAllNotes(pin);
          await pinService.deletePin();
          try {
            final dbPath = await getDatabasesPath();
            final vaultFile = File(path_helper.join(dbPath, 'dokki_vault.enc'));
            if (await vaultFile.exists()) await vaultFile.delete();
          } catch (_) {}
          syncStatusService.updateStatus(SyncStatus.disabled);
          if (mounted) setState(() => _isSyncEnabled = false);
        }
      }
    }
  }

  Future<void> _showErrorDialog() async {
    if (!mounted) return;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Icon(Icons.error_outline, color: Colors.red, size: 80),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(CupertinoIcons.checkmark_circle_fill,
                color: Colors.grey.withValues(alpha: 0.7), size: 48),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  Future<bool?> _showDisableSyncConfirm() async {
    if (!mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Icon(Icons.cloud_off, color: Colors.red, size: 80),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: Icon(CupertinoIcons.xmark_circle,
                color: Colors.grey.withValues(alpha: 0.7), size: 48),
          ),
          const SizedBox(width: 48),
          IconButton(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(CupertinoIcons.checkmark_circle_fill,
                color: Colors.red, size: 48),
          ),
        ],
      ),
    );
  }

  // --- Изменение 4 ---
  Future<void> _decryptAllNotes(String pin) async {
    encryptionService.init(pin);
    final allNotes = await DBService.db.getAllNotes();
    final trashNotes = await DBService.db.getTrashNotes();
    final notes = [...allNotes, ...trashNotes];
    for (var note in notes) {
      try {
        final title = encryptionService.decryptText(note.title);
        final content = encryptionService.decryptText(note.content);
        await DBService.db
            .updateNote(note.copyWith(title: title, content: content));
      } catch (_) {}
    }
    encryptionService.clearKey();
  }
  // -------------------

  Future<void> _loadTrashCount() async {
    final trashNotes = await DBService.db.getTrashNotes();
    if (mounted) setState(() => _trashCount = trashNotes.length);
  }

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
      prefs.isDarkMode = value;
    });
  }

  void _toggleBiometric(bool value) async {
    final success = await SecurityService().setBiometricEnabled(value);
    if (success) {
      await prefs.setBiometricEnabled(value);
      if (mounted) setState(() => _isBiometricEnabled = value);
    } else {
      if (mounted) setState(() => _isBiometricEnabled = _isBiometricEnabled);
    }
  }

  IconData _getSyncIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return CupertinoIcons.cloud_fill;
      case SyncStatus.uploading:
        return CupertinoIcons.cloud_upload;
      case SyncStatus.downloading:
        return CupertinoIcons.cloud_download;
      case SyncStatus.error:
        return CupertinoIcons.exclamationmark_triangle;
      default:
        return CupertinoIcons.cloud;
    }
  }

  Color _getSyncColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return DokkiColors.primaryTeal;
      case SyncStatus.uploading:
      case SyncStatus.downloading:
        return Colors.orange;
      case SyncStatus.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color teal = DokkiColors.primaryTeal;
    final Color grey = Colors.grey.withValues(alpha: 0.65);
    final bool isAuth = AuthService.instance.isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, size: 28),
          onPressed: () => Navigator.pop(context),
          splashRadius: 28,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ListTile(
              leading: Icon(
                Icons.account_circle,
                color: isAuth ? const Color(0xFF00BCD4) : Colors.grey[600],
                size: 32,
              ),
              trailing: Icon(
                Icons.person_add,
                color: isAuth ? const Color(0xFF00BCD4) : Colors.grey[600],
                size: 24,
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
                if (mounted) {
                  setState(() {});
                  await _loadBalance();
                }
              },
            ),
            ListTile(
              leading: const AiMicIcon(
                size: 32,
                color: Color(0xFFFFD700),
              ),
              trailing: Text(
                '$_balance',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 18,
                ),
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PaywallScreen()),
                );
                if (mounted) {
                  setState(() {});
                  await _loadBalance();
                }
              },
            ),
            const Divider(color: Colors.grey, height: 32),
            _MinimalIconRow(
              left: const Icon(CupertinoIcons.moon_fill, size: 32),
              right: CupertinoSwitch(
                value: _isDarkMode,
                onChanged: _toggleTheme,
                activeTrackColor: teal,
                inactiveTrackColor: grey.withValues(alpha: 0.22),
              ),
            ),
            const SizedBox(height: 32),
            _MinimalIconRow(
              left: const Icon(CupertinoIcons.lock_fill, size: 32),
              right: CupertinoSwitch(
                value: _isBiometricEnabled,
                onChanged: _toggleBiometric,
                activeTrackColor: teal,
                inactiveTrackColor: grey.withValues(alpha: 0.22),
              ),
            ),
            const SizedBox(height: 32),
            _MinimalIconRow(
              left: SvgPicture.asset(
                'assets/icons/sort_general.svg',
                width: 32,
                height: 32,
                colorFilter: ColorFilter.mode(
                    Colors.grey.withValues(alpha: 0.65), BlendMode.srcIn),
              ),
              right: GestureDetector(
                onTap: () => setState(() =>
                    prefs.sortType = prefs.sortType == 'desc' ? 'az' : 'desc'),
                child: SvgPicture.asset(
                  prefs.sortType == 'desc'
                      ? 'assets/icons/calendar.svg'
                      : 'assets/icons/sort_az.svg',
                  width: 32,
                  height: 32,
                  colorFilter: const ColorFilter.mode(
                      DokkiColors.primaryTeal, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _MinimalIconRow(
              left: const Icon(CupertinoIcons.cloud, size: 32),
              right: StreamBuilder<SyncStatus>(
                stream: syncStatusService.statusStream,
                initialData:
                    _isSyncEnabled ? SyncStatus.synced : SyncStatus.disabled,
                builder: (context, snapshot) {
                  final status = snapshot.data ?? SyncStatus.disabled;
                  return Row(
                    children: [
                      Icon(_getSyncIcon(status),
                          color: _getSyncColor(status), size: 32),
                      const SizedBox(width: 12),
                      CupertinoSwitch(
                        value: _isSyncEnabled,
                        onChanged: _toggleSync,
                        activeTrackColor: DokkiColors.primaryTeal,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TrashScreen()));
                _loadTrashCount();
              },
              child: _MinimalIconRow(
                left: const Icon(CupertinoIcons.trash,
                    size: 32, color: Colors.redAccent),
                right: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Text(
                    '$_trashCount',
                    style: TextStyle(
                      color: _trashCount > 0 ? Colors.redAccent : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _MinimalIconRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _MinimalIconRow({required this.left, required this.right});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [left, right],
      ),
    );
  }
}
