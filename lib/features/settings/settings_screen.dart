import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dytty/features/settings/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSection(
            theme,
            'Notifications',
            [
              SwitchListTile(
                title: const Text('Daily reminder'),
                subtitle: const Text('Get reminded to journal each day'),
                value: settings.notificationsEnabled,
                onChanged: (v) => settings.setNotificationsEnabled(v),
              ),
              ListTile(
                title: const Text('Reminder time'),
                subtitle: Text(settings.reminderTimeFormatted),
                trailing: const Icon(Icons.chevron_right),
                enabled: settings.notificationsEnabled,
                onTap: settings.notificationsEnabled
                    ? () => _pickTime(context, settings)
                    : null,
              ),
            ],
          ),
          _buildSection(
            theme,
            'About',
            [
              const ListTile(
                title: Text('Version'),
                subtitle: Text('0.1.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      ),
    );
    if (picked != null) {
      await settings.setReminderTime(picked.hour, picked.minute);
    }
  }
}
