import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';
import '../services/prefs_service.dart';
import '../services/db_service.dart';
import '../services/sync_status_service.dart';
import '../services/auth_service.dart';
import '../services/railway_service.dart';
import '../services/google_drive_service.dart';
import '../services/pin_service.dart';
import '../widgets/pin_input_dialog.dart';
import '../theme/dokki_theme.dart';
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
  bool _isPinEnabled = false;
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
    _loadPinState();
    _loadTrashCount();
    _loadSyncState();
    _loadBalance();
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

  Future<void> _loadPinState() async {
    final hasPin = await pinService.hasPin();
    if (mounted) setState(() => _isPinEnabled = hasPin);
  }

  Future<void> _loadSyncState() async {
    final signedIn = await GoogleDriveService().isSignedIn();
    DBService.db.setGoogleSyncEnabled(signedIn);
    if (mounted) {
      setState(() {
        _isSyncEnabled = signedIn;
      });
    }
  }

  Future<void> _toggleSync(bool value) async {
    if (!mounted) return;

    if (value) {
      final success = await GoogleDriveService().signIn();
      if (!success) {
        if (mounted) syncStatusService.updateStatus(SyncStatus.error);
        return;
      }

      syncStatusService.updateStatus(SyncStatus.uploading);
      final uploaded = await GoogleDriveService().uploadNotes();

      syncStatusService.updateStatus(
        uploaded ? SyncStatus.synced : SyncStatus.error,
      );

      if (mounted) setState(() => _isSyncEnabled = uploaded);
      DBService.db.setGoogleSyncEnabled(uploaded);
    } else {
      final confirmed = await _showDisableSyncConfirm();
      if (confirmed == true) {
        await GoogleDriveService().signOut();
        syncStatusService.updateStatus(SyncStatus.disabled);
        DBService.db.setGoogleSyncEnabled(false);
        if (mounted) setState(() => _isSyncEnabled = false);
      }
    }
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

  Future<void> _togglePin(bool value) async {
    if (!mounted) return;

    // Сначала пробуем биометрию
    bool biometricPassed = false;
    try {
      final localAuth = LocalAuthentication();
      final available = await localAuth.canCheckBiometrics;
      if (available) {
        biometricPassed = await localAuth.authenticate(
          localizedReason: value ? 'Enable note lock' : 'Disable note lock',
          options: const AuthenticationOptions(
            stickyAuth: false,
            biometricOnly: true,
          ),
        );
      }
    } catch (_) {}

    if (value) {
      if (!biometricPassed) {
        if (!mounted) return;
        final pin = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PinInputDialog(
            title: 'Create PIN (4-8 digits)',
            isConfirmation: true,
          ),
        );
        if (pin == null || pin.length < 4) return;
        await pinService.setPin(pin);
      } else {
        // Биометрия прошла — сохраняем специальный маркер
        await pinService.setPin('biometric_only');
      }
      if (mounted) setState(() => _isPinEnabled = true);
    } else {
      if (!biometricPassed) {
        // Fallback — ввести PIN
        if (!mounted) return;
        final pin = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PinInputDialog(
            title: 'Enter PIN to disable',
            isConfirmation: false,
          ),
        );
        if (pin == null || !await pinService.verifyPin(pin)) return;
      }
      final notes = await DBService.db.getAllNotes();
      for (final note in notes) {
        if (note.isLocked == 1) {
          await DBService.db.updateNote(note.copyWith(isLocked: 0));
        }
      }
      await pinService.deletePin();
      if (mounted) setState(() => _isPinEnabled = false);
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
              left: const Icon(CupertinoIcons.lock_shield, size: 32),
              right: CupertinoSwitch(
                value: _isPinEnabled,
                onChanged: _togglePin,
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
