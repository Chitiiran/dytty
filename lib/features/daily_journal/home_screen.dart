import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dytty/core/utils/menu_position_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';
import 'package:dytty/features/daily_journal/widgets/category_radial_menu.dart';
import 'package:dytty/features/daily_journal/widgets/completion_ring_cell.dart';
import 'package:dytty/features/daily_journal/widgets/entry_bottom_sheet.dart';
import 'package:dytty/features/voice_note/widgets/voice_recording_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  OverlayEntry? _radialMenuOverlay;
  Offset? _lastTapGlobalPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JournalBloc>().add(SelectDate(DateTime.now()));
    });
  }

  @override
  void dispose() {
    _dismissRadialMenu();
    super.dispose();
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
    final categoryState = context.watch<CategoryCubit>().state;
    final theme = Theme.of(context);

    final displayName = authState is Authenticated
        ? authState.displayName?.split(' ').first ?? 'there'
        : 'there';
    final photoUrl = authState is Authenticated ? authState.photoUrl : null;
    final userName = authState is Authenticated ? authState.displayName : null;

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Today button',
                  button: true,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        final today = DateTime.now();
                        setState(() {
                          _focusedDay = today;
                        });
                        context.read<JournalBloc>().add(SelectDate(today));
                        Navigator.pushNamed(context, '/daily-journal');
                      },
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Write'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.large(
                onPressed: () => _openVoiceNote(context),
                tooltip: 'Record voice note',
                elevation: 2,
                child: const Icon(Icons.mic_rounded, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/voice-call');
                    },
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                  child: Listener(
                    onPointerDown: (event) {
                      _lastTapGlobalPosition = event.position;
                    },
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
                          context.read<JournalBloc>().add(
                            SelectDate(selectedDay),
                          );
                          _showRadialMenu(
                            context,
                            selectedDay,
                            tapPosition: _lastTapGlobalPosition,
                          );
                        },
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                          context.read<JournalBloc>().add(
                            LoadMonthMarkers(
                              year: focusedDay.year,
                              month: focusedDay.month,
                            ),
                          );
                        },
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) =>
                              CompletionRingCell(
                                day: day,
                                categoryMarkers:
                                    journalState
                                        .monthCategoryMarkers[_dateFormat
                                        .format(day)],
                                activeCategories:
                                    categoryState.activeCategories,
                              ),
                          todayBuilder: (context, day, focusedDay) =>
                              CompletionRingCell(
                                day: day,
                                categoryMarkers:
                                    journalState
                                        .monthCategoryMarkers[_dateFormat
                                        .format(day)],
                                activeCategories:
                                    categoryState.activeCategories,
                                isToday: true,
                              ),
                          selectedBuilder: (context, day, focusedDay) =>
                              CompletionRingCell(
                                day: day,
                                categoryMarkers:
                                    journalState
                                        .monthCategoryMarkers[_dateFormat
                                        .format(day)],
                                activeCategories:
                                    categoryState.activeCategories,
                                isSelected: true,
                                isToday: isSameDay(day, DateTime.now()),
                              ),
                        ),
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
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Nudge card — show if no entries today
                if (!journalState.journaledToday)
                  Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _NudgeCard(onTap: () => _openVoiceNote(context)),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms),

                if (!journalState.journaledToday) const SizedBox(height: 12),

                // Progress card
                Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ProgressCard(
                        entries: journalState.entries,
                        categories: categoryState.activeCategories,
                        selectedDate: journalState.selectedDate,
                        currentStreak: journalState.currentStreak,
                        onCategoryTap: (categoryId) {
                          Navigator.pushNamed(
                            context,
                            '/category-detail',
                            arguments: categoryId,
                          );
                        },
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, duration: 400.ms),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SnackBar _buildVoiceNoteSnackBar(
    BuildContext context, {
    required CategoryConfig category,
    required String text,
  }) {
    final theme = Theme.of(context);
    final preview = text.length > 60 ? '${text.substring(0, 60)}...' : text;

    return SnackBar(
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: theme.colorScheme.inverseSurface,
      content: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(category.icon, size: 16, color: category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved to ${category.displayName}',
                  style: TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  style: TextStyle(
                    color: theme.colorScheme.onInverseSurface.withValues(
                      alpha: 0.7,
                    ),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _dismissRadialMenu() {
    _radialMenuOverlay?.remove();
    _radialMenuOverlay = null;
  }

  void _showRadialMenu(
    BuildContext context,
    DateTime selectedDay, {
    Offset? tapPosition,
  }) {
    _dismissRadialMenu();

    final categoryState = context.read<CategoryCubit>().state;
    final journalBloc = context.read<JournalBloc>();

    // Read from monthCategoryMarkers — always populated by calendar
    final dateStr = _dateFormat.format(selectedDay);
    final filledCounts = Map<String, int>.from(
      journalBloc.state.monthCategoryMarkers[dateStr] ?? {},
    );

    // Categories for this date: active + archived with entries
    final categories = <CategoryConfig>[];
    final entryIds = filledCounts.keys.toSet();
    for (final cat in categoryState.categories) {
      if (!cat.isArchived || entryIds.contains(cat.id)) {
        categories.add(cat);
      }
    }
    categories.sort((a, b) => a.order.compareTo(b.order));

    // Need at least 2 for circular_menu
    if (categories.length < 2) return;

    final screenSize = MediaQuery.of(context).size;
    const menuSize = 250.0;
    const menuPadding = 16.0;

    // Fall back to screen center if no tap position
    final effectiveTap =
        tapPosition ?? Offset(screenSize.width / 2, screenSize.height / 2);

    final menuOffset = clampMenuPosition(
      tapPosition: effectiveTap,
      screenSize: screenSize,
      menuSize: menuSize,
      padding: menuPadding,
    );

    _radialMenuOverlay = OverlayEntry(
      builder: (overlayContext) => Material(
        color: Colors.black54,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismissRadialMenu,
          child: Stack(
            children: [
              Positioned(
                left: menuOffset.dx,
                top: menuOffset.dy,
                child: GestureDetector(
                  onTap: () {}, // Absorb taps on the menu itself
                  child: SizedBox(
                    width: menuSize,
                    height: menuSize,
                    child: CategoryRadialMenu(
                      categories: categories,
                      filledCounts: filledCounts,
                      onCategoryTap: (category) async {
                        _dismissRadialMenu();
                        final selectedDate = selectedDay;

                        if (category.isArchived) {
                          if (context.mounted) {
                            Navigator.pushNamed(
                              context,
                              '/category-detail',
                              arguments: category.id,
                            );
                          }
                          return;
                        }

                        if (!context.mounted) return;
                        final text = await showEntryBottomSheet(
                          context,
                          category: category,
                        );
                        if (text != null && context.mounted) {
                          journalBloc.add(
                            AddEntry(
                              categoryId: category.id,
                              text: text,
                              date: selectedDate,
                            ),
                          );
                        }
                      },
                      onVoiceTap: () {
                        _dismissRadialMenu();
                        Navigator.pushNamed(context, '/voice-call');
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_radialMenuOverlay!);
  }

  Future<void> _openVoiceNote(BuildContext context) async {
    final result = await showVoiceRecordingSheet(context);
    if (result == null || !context.mounted) return;

    final bloc = context.read<JournalBloc>();
    final today = DateTime.now();
    bloc.add(
      AddVoiceEntry(
        categoryId: result.categoryId,
        text: result.text,
        transcript: result.transcript,
        tags: result.tags,
        date: today,
      ),
    );

    if (context.mounted) {
      final categoryState = context.read<CategoryCubit>().state;
      final category = categoryState.findById(result.categoryId);

      Navigator.pushNamed(context, '/daily-journal');
      if (category != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildVoiceNoteSnackBar(
            context,
            category: category,
            text: result.text,
          ),
        );
      }
    }
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
  final List<CategoryEntry> entries;
  final List<CategoryConfig> categories;
  final int currentStreak;
  final DateTime selectedDate;
  final void Function(String categoryId)? onCategoryTap;

  const _ProgressCard({
    required this.entries,
    required this.categories,
    required this.selectedDate,
    this.currentStreak = 0,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filledCategoryIds = <String>{};
    for (final entry in entries) {
      filledCategoryIds.add(entry.categoryId);
    }
    final total = categories.length;
    final filled = filledCategoryIds
        .intersection(categories.map((c) => c.id).toSet())
        .length;
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

    return Semantics(
      label:
          'Progress $filled of $total${currentStreak > 0 ? ', streak $currentStreak day${currentStreak == 1 ? '' : 's'}' : ''}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isSameDay(selectedDate, DateTime.now())
                        ? "Today's Progress"
                        : '${DateFormat('MMM d').format(selectedDate)} Progress',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (currentStreak > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$currentStreak day${currentStreak == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                children: categories.map((cat) {
                  final isFilled = filledCategoryIds.contains(cat.id);
                  return Tooltip(
                    message: '${cat.displayName} detail',
                    child: InkWell(
                      onTap: () => onCategoryTap?.call(cat.id),
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
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
                                  : theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.3),
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
                      ),
                    ),
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
      ),
    );
  }
}

class _NudgeCard extends StatelessWidget {
  final VoidCallback onTap;

  const _NudgeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 20,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You haven't journaled today",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'It only takes a minute.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
