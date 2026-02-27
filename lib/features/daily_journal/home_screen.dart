import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dytty/features/auth/auth_provider.dart';
import 'package:dytty/features/daily_journal/journal_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final journal = context.read<JournalProvider>();
      journal.loadMonthMarkers(_focusedDay.year, _focusedDay.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dytty'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: authProvider.signOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Column(
        children: [
          Semantics(
            label: 'Calendar',
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) =>
                  isSameDay(journalProvider.selectedDate, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
                journalProvider.selectDate(selectedDay);
                Navigator.pushNamed(context, '/daily-journal');
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                journalProvider.loadMonthMarkers(
                  focusedDay.year,
                  focusedDay.month,
                );
              },
              eventLoader: (day) {
                final dateStr = _dateFormat.format(day);
                return journalProvider.daysWithEntries.contains(dateStr)
                    ? ['entry']
                    : [];
              },
              calendarStyle: CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                markerSize: 6,
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              label: 'Today button',
              button: true,
              child: FilledButton.icon(
                onPressed: () {
                  final today = DateTime.now();
                  setState(() {
                    _focusedDay = today;
                  });
                  journalProvider.selectDate(today);
                  Navigator.pushNamed(context, '/daily-journal');
                },
                icon: const Icon(Icons.edit_note),
                label: const Text("Today's Journal"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
