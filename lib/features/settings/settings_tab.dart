import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_sonic/features/settings/palette_personalizer_screen.dart';
import 'package:manga_sonic/features/auth/auth_screen.dart';
import 'package:manga_sonic/services/auth_service.dart';
import 'package:manga_sonic/services/sync_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Theme Section
          _buildSectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme Personalization'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PalettePersonalizerScreen(),
                ),
              );
            },
          ),

          // Authentication Section
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return Column(
                children: [
                  _buildSectionHeader('Account'),
                  if (!authService.isSignedIn) ...[
                    ListTile(
                      leading: const Icon(Icons.person_add_outlined),
                      title: const Text('Sign In / Sign Up'),
                      subtitle: const Text('Sync library and reading progress across devices'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AuthScreen(),
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          authService.userEmail?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(authService.userEmail ?? 'Signed in'),
                      subtitle: const Text('Tap to sign out'),
                      onTap: () => _showSignOutDialog(context, authService),
                    ),
                    // Change Password
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change Password'),
                      subtitle: const Text('Update your account password'),
                      onTap: () => _showChangePasswordDialog(context, authService),
                    ),
                    Consumer<SyncService>(
                      builder: (context, syncService, child) {
                        return Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                syncService.isSyncing 
                                    ? Icons.sync 
                                    : syncService.isOnline 
                                        ? Icons.cloud_done 
                                        : Icons.cloud_off,
                                color: syncService.isSyncing 
                                    ? Theme.of(context).colorScheme.primary 
                                    : syncService.isOnline 
                                        ? Colors.green 
                                        : Colors.orange,
                              ),
                              title: const Text('Sync Status'),
                              subtitle: Text(
                                syncService.isSyncing
                                    ? 'Syncing...'
                                    : syncService.isOnline
                                        ? 'Last sync: ${_formatLastSync(syncService.lastSuccessfulSync)}'
                                        : 'Offline - changes will sync when online',
                              ),
                              trailing: syncService.isSyncing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.sync),
                                      onPressed: syncService.isOnline 
                                          ? () => syncService.forceSync() 
                                          : null,
                                      tooltip: 'Sync Now',
                                    ),
                            ),
                            if (syncService.lastSyncError != null) ...[
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        syncService.lastSyncError!,
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            ListTile(
                              leading: const Icon(Icons.info_outline),
                              title: const Text('Pending Changes'),
                              subtitle: Text(
                                '${syncService.pendingLibraryChangesCount} library, ${syncService.pendingProgressChangesCount} progress',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),

          // About Section
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.1'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? Your local library and reading progress will remain on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authService.signOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, AuthService authService) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Change Password'),
          content: SizedBox(
            width: 350,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrent,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                        onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter current password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                        onPressed: () => setState(() => obscureNew = !obscureNew),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter new password';
                      if (value.length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                        onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Confirm new password';
                      if (value != newPasswordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            Consumer<AuthService>(
              builder: (context, authService, child) {
                return ElevatedButton(
                  onPressed: authService.authState == AuthState.loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          // Update password
                          final success = await authService.updatePassword(newPasswordController.text);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Password updated successfully' : 'Failed: ${authService.authError}'),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: authService.authState == AuthState.loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Update Password'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSync(DateTime? dateTime) {
    if (dateTime == null) return 'Never';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
