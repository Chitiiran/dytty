import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/settings/cubit/settings_cubit.dart';
import 'package:dytty/features/settings/cubit/theme_cubit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.buildNumber.isNotEmpty
            ? '${info.version}+${info.buildNumber}'
            : info.version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final themeMode = context.watch<ThemeCubit>().state;
    final settingsState = context.watch<SettingsCubit>().state;
    final theme = Theme.of(context);

    final displayName = authState is Authenticated
        ? authState.displayName
        : null;
    final email = authState is Authenticated ? authState.email : null;
    final photoUrl = authState is Authenticated ? authState.photoUrl : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header
          if (authState is Authenticated)
            Center(
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: photoUrl != null
                              ? Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildInitials(displayName, theme),
                                )
                              : _buildInitials(displayName, theme),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName ?? 'User',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (email != null && email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1, 1),
                  duration: 400.ms,
                ),

          const SizedBox(height: 24),

          // Appearance section
          _SectionLabel(label: 'Appearance'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _ThemeTile(
                    icon: Icons.brightness_auto_rounded,
                    label: 'System',
                    selected: themeMode == ThemeMode.system,
                    onTap: () => context.read<ThemeCubit>().setThemeMode(
                      ThemeMode.system,
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  _ThemeTile(
                    icon: Icons.light_mode_rounded,
                    label: 'Light',
                    selected: themeMode == ThemeMode.light,
                    onTap: () => context.read<ThemeCubit>().setThemeMode(
                      ThemeMode.light,
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  _ThemeTile(
                    icon: Icons.dark_mode_rounded,
                    label: 'Dark',
                    selected: themeMode == ThemeMode.dark,
                    onTap: () =>
                        context.read<ThemeCubit>().setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Journal section
          _SectionLabel(label: 'Journal'),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.visibility_off_rounded),
              title: const Text('Hide entries'),
              subtitle: const Text('Show entries in weekly review only'),
              value: settingsState.hideEntries,
              onChanged: (_) =>
                  context.read<SettingsCubit>().toggleHideEntries(),
            ),
          ),

          const SizedBox(height: 20),

          // Reminders section
          _SectionLabel(label: 'Reminders'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Daily reminder'),
                  subtitle: const Text('Get reminded to journal'),
                  value: settingsState.reminderEnabled,
                  onChanged: (_) =>
                      context.read<SettingsCubit>().toggleReminder(),
                ),
                if (settingsState.reminderEnabled) ...[
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time_rounded),
                    title: const Text('Reminder time'),
                    trailing: Text(
                      settingsState.reminderTime.format(context),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: settingsState.reminderTime,
                      );
                      if (picked != null && context.mounted) {
                        context.read<SettingsCubit>().setReminderTime(picked);
                      }
                    },
                  ),
                ],
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.phone_rounded),
                  title: const Text('Daily call reminder'),
                  subtitle: const Text('Get reminded to start your daily call'),
                  value: settingsState.dailyCallEnabled,
                  onChanged: (_) =>
                      context.read<SettingsCubit>().toggleDailyCall(),
                ),
                if (settingsState.dailyCallEnabled) ...[
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time_rounded),
                    title: const Text('Call time'),
                    trailing: Text(
                      settingsState.dailyCallTime.format(context),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: settingsState.dailyCallTime,
                      );
                      if (picked != null && context.mounted) {
                        context.read<SettingsCubit>().setDailyCallTime(picked);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Account section
          _SectionLabel(label: 'Account'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Sign Out',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onTap: () async {
                context.read<AuthBloc>().add(const SignOut());
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ),

          const SizedBox(height: 20),

          // About section
          _SectionLabel(label: 'About'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Version'),
                    trailing: Text(
                      _version.isEmpty ? '...' : _version,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Licenses'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Dytty',
                      applicationVersion: _version.isEmpty ? null : _version,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInitials(String? name, ThemeData theme) {
    final initial = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : '?';
    return Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: selected ? theme.colorScheme.primary : null),
      title: Text(label),
      trailing: selected
          ? Icon(
              Icons.check_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            )
          : null,
      onTap: onTap,
    );
  }
}
