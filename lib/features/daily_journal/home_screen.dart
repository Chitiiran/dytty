import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:dytty/features/daily_journal/daily_journal_screen.dart';
import 'package:dytty/features/daily_journal/journal_provider.dart';
import 'package:dytty/features/settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<DateTime> _markedDays = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    final provider = context.read<JournalProvider>();
    final days = await provider.getDaysWithEntries(
      _focusedDay.year,
      _focusedDay.month,
    );
    setState(() => _markedDays = days);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _openDay(selectedDay);
  }

  void _openDay(DateTime day) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyJournalScreen(date: day),
      ),
    ).then((_) => _loadMarkers());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dytty'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadMarkers();
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
              markerSize: 6,
            ),
            eventLoader: (day) {
              final normalized = DateTime(day.year, day.month, day.day);
              return _markedDays.contains(normalized) ? [true] : [];
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _selectedDay != null
                  ? DateFormat.yMMMMd().format(_selectedDay!)
                  : 'Select a day',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const Spacer(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDay(today),
        icon: const Icon(Icons.edit),
        label: const Text("Today's Journal"),
      ),
    );
  }
}
