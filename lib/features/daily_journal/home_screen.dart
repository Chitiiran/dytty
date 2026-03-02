import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';

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
      final bloc = context.read<JournalBloc>();
      bloc.add(LoadMonthMarkers(
        year: _focusedDay.year,
        month: _focusedDay.month,
      ));
      bloc.add(SelectDate(DateTime.now()));
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final journalState = context.watch<JournalBloc>().state;
    final theme = Theme.of(context);

    final displayName = authState is Authenticated
        ? authState.displayName?.split(' ').first ?? 'there'
        : 'there';
    final photoUrl =
        authState is Authenticated ? authState.photoUrl : null;
    final userName =
        authState is Authenticated ? authState.displayName : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Dytty'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Settings',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: _UserAvatar(
                photoUrl: photoUrl,
                displayName: userName,
                size: 34,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Text(
                        '${_greeting()}, $displayName',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.05, end: 0, duration: 400.ms),

                // Calendar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Semantics(
                    label: 'Calendar',
                    child: TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) =>
                          isSameDay(journalState.selectedDate, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                        context
                            .read<JournalBloc>()
                            .add(SelectDate(selectedDay));
                        Navigator.pushNamed(context, '/daily-journal');
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                        context.read<JournalBloc>().add(LoadMonthMarkers(
                              year: focusedDay.year,
                              month: focusedDay.month,
                            ));
                      },
                      eventLoader: (day) {
                        final dateStr = _dateFormat.format(day);
                        return journalState.daysWithEntries.contains(dateStr)
                            ? ['entry']
                            : [];
                      },
                      headerStyle: HeaderStyle(
                        formatButtonVisible: true,
                        titleCentered: true,
                        formatButtonShowsNext: false,
                        titleTextStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        formatButtonDecoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        formatButtonPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left_rounded,
                          color: theme.colorScheme.onSurface,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        markerDecoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        markerSize: 6,
                        todayDecoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        outsideDaysVisible: false,
                        weekendTextStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        weekendStyle: TextStyle(
                          color:
                              theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Progress card
                Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child:
                          _ProgressCard(entries: journalState.entries),
                    )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, duration: 400.ms),

                const SizedBox(height: 16),

                // Today button
                Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        label: 'Today button',
                        button: true,
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () {
                              final today = DateTime.now();
                              setState(() {
                                _focusedDay = today;
                              });
                              context
                                  .read<JournalBloc>()
                                  .add(SelectDate(today));
                              Navigator.pushNamed(context, '/daily-journal');
                            },
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text("Write Today's Journal"),
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 350.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, duration: 400.ms),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;
  final double size;

  const _UserAvatar({
    required this.photoUrl,
    required this.displayName,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = displayName ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: photoUrl != null
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _InitialsAvatar(initials: initials, theme: theme),
              )
            : _InitialsAvatar(initials: initials, theme: theme),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final ThemeData theme;

  const _InitialsAvatar({required this.initials, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final List entries;

  const _ProgressCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filledCategories = <JournalCategory>{};
    for (final entry in entries) {
      filledCategories.add(entry.category);
    }
    final total = JournalCategory.values.length;
    final filled = filledCategories.length;
    final progress = total > 0 ? filled / total : 0.0;

    String message;
    if (filled == 0) {
      message = 'Start your daily reflection';
    } else if (filled < total) {
      message =
          'Keep going! ${total - filled} ${total - filled == 1 ? 'category' : 'categories'} left';
    } else {
      message = 'All categories complete!';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Today's Progress",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$filled/$total',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Category icons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: JournalCategory.values.map((cat) {
                final isFilled = filledCategories.contains(cat);
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isFilled
                            ? cat.color.withValues(alpha: 0.15)
                            : theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        cat.icon,
                        size: 20,
                        color: isFilled
                            ? cat.color
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.3,
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isFilled)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 6),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                color: filled == total
                    ? const Color(0xFF10B981)
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
