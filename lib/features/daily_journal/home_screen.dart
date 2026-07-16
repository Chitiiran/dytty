import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dytty/core/utils/radial_arc_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';
import 'package:dytty/features/daily_journal/widgets/category_radial_menu.dart';
import 'package:dytty/features/daily_journal/widgets/completion_ring_cell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  /// Radial-pinned progress-card date (#256): null = resting state, where
  /// the card reports on today COMPUTED AT BUILD (a field default captured
  /// at State creation would show yesterday after midnight — #268 review).
  /// Set by a radial selection; cleared by the go-to-today button.
  DateTime? _pinnedProgressDate;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  Route<void>? _radialMenuRoute;
  Offset? _lastTapGlobalPosition;

  /// Stable key per visible day cell so the radial menu can anchor to the
  /// tapped cell's center instead of the raw tap position (#188).
  ///
  /// INVARIANT: relies on `outsideDaysVisible: false` on the calendar.
  /// table_calendar renders outside days before the custom builders only
  /// when they are hidden; with visible outside days a selected/today
  /// boundary date would build on BOTH adjacent month pages mid-swipe and
  /// duplicate a GlobalKey (framework crash).
  final Map<String, GlobalKey> _dayCellKeys = {};

  GlobalKey _dayCellKey(DateTime day) =>
      _dayCellKeys.putIfAbsent(_dateFormat.format(day), GlobalKey.new);

  /// LayerLink per day cell: the open radial menu follows the cell through
  /// any layout shift (keyboard insets, scroll settling) instead of being
  /// pinned to coordinates captured at open. Same one-target-per-day
  /// invariant as [_dayCellKeys].
  final Map<String, LayerLink> _dayCellLinks = {};

  LayerLink _dayCellLink(DateTime day) =>
      _dayCellLinks.putIfAbsent(_dateFormat.format(day), LayerLink.new);

  /// Global center of the rendered cell for [day], or null if not laid out.
  Offset? _dayCellCenter(DateTime day) {
    final box =
        _dayCellKeys[_dateFormat.format(day)]?.currentContext
                ?.findRenderObject()
            as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JournalBloc>().add(SelectDate(DateTime.now()));
    });
  }

  @override
  void dispose() {
    // The menu is a navigator route; the navigator disposes it with the
    // screen — popping here would be an unsafe navigator call mid-teardown.
    _radialMenuRoute = null;
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
              const Spacer(),
              // #251/#256: the mic FAB IS the bottom bar — sole capture entry.
              FloatingActionButton.large(
                onPressed: () => _startTodayCall(context),
                tooltip: 'Start daily call',
                elevation: 2,
                child: const Icon(Icons.mic_rounded, size: 32),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text('Dytty'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            // Semantics wrapper: the tooltip alone was not findable by
            // automation/screen readers (glossary a11y gap, #255/#256).
            // Label-only node: the button role/action lives on the inner
            // IconButton (#268 review — an action-less outer button node
            // confuses TalkBack).
            child: Semantics(
              label: 'Settings',
              container: true,
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

                // Load failure feedback with retry (#170)
                if (journalState.error != null)
                  MaterialBanner(
                    leading: Icon(
                      Icons.cloud_off_rounded,
                      color: theme.colorScheme.error,
                    ),
                    content: const Text("Couldn't load your journal data."),
                    actions: [
                      TextButton(
                        onPressed: () => context.read<JournalBloc>().add(
                          SelectDate(journalState.selectedDate),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),

                if (journalState.status == JournalStatus.loading)
                  const LinearProgressIndicator(minHeight: 2),

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
                            // card follows the selection (#256)
                            _pinnedProgressDate = selectedDay;
                          });
                          context.read<JournalBloc>().add(
                            SelectDate(selectedDay),
                          );
                          _showRadialMenu(
                            context,
                            selectedDay,
                            // Anchor to the cell center; fall back to the
                            // tap position when the cell has no key/box —
                            // e.g. outside days in week/two-week formats,
                            // which skip the custom builders (#188).
                            anchor:
                                _dayCellCenter(selectedDay) ??
                                _lastTapGlobalPosition,
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
                              CompositedTransformTarget(
                                link: _dayCellLink(day),
                                child: KeyedSubtree(
                                  key: _dayCellKey(day),
                                  child: CompletionRingCell(
                                    day: day,
                                    categoryMarkers:
                                        journalState
                                            .monthCategoryMarkers[_dateFormat
                                            .format(day)],
                                    activeCategories:
                                        categoryState.activeCategories,
                                  ),
                                ),
                              ),
                          todayBuilder: (context, day, focusedDay) =>
                              CompositedTransformTarget(
                                link: _dayCellLink(day),
                                child: KeyedSubtree(
                                  key: _dayCellKey(day),
                                  child: CompletionRingCell(
                                    day: day,
                                    categoryMarkers:
                                        journalState
                                            .monthCategoryMarkers[_dateFormat
                                            .format(day)],
                                    activeCategories:
                                        categoryState.activeCategories,
                                    isToday: true,
                                  ),
                                ),
                              ),
                          selectedBuilder: (context, day, focusedDay) =>
                              CompositedTransformTarget(
                                link: _dayCellLink(day),
                                child: KeyedSubtree(
                                  key: _dayCellKey(day),
                                  child: CompletionRingCell(
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
                        child: _NudgeCard(
                          onTap: () => _startTodayCall(context),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms),

                if (!journalState.journaledToday) const SizedBox(height: 12),

                // Progress card
                Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Builder(
                        builder: (context) {
                          // #256 refines #154: today-sourced at rest, but the
                          // card follows the radial's selected date until the
                          // go-to-today reset.
                          final progressDate =
                              _pinnedProgressDate ?? DateTime.now();
                          final progressIsToday = DateUtils.isSameDay(
                            progressDate,
                            DateTime.now(),
                          );
                          final filled = progressIsToday
                              ? journalState.todayCategoryCounts.keys.toSet()
                              : (journalState.monthCategoryMarkers[_dateFormat
                                            .format(progressDate)] ??
                                        const <String, int>{})
                                    .keys
                                    .toSet();
                          return _ProgressCard(
                            filledCategoryIds: filled,
                            categories: categoryState.activeCategories,
                            date: progressDate,
                            isToday: progressIsToday,
                            currentStreak: journalState.currentStreak,
                            onCategoryTap: (categoryId) {
                              Navigator.pushNamed(
                                context,
                                '/category-detail',
                                arguments: categoryId,
                              );
                            },
                            onBodyTap: () {
                              context.read<JournalBloc>().add(
                                SelectDate(progressDate),
                              );
                              Navigator.pushNamed(context, '/daily-journal');
                            },
                            onGoToToday: () => setState(() {
                              _pinnedProgressDate = null;
                            }),
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

  void _dismissRadialMenu() {
    final route = _radialMenuRoute;
    _radialMenuRoute = null;
    if (route != null && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  void _showRadialMenu(
    BuildContext context,
    DateTime selectedDay, {
    Offset? anchor,
  }) {
    _dismissRadialMenu();

    final categoryState = context.read<CategoryCubit>().state;
    final journalBloc = context.read<JournalBloc>();
    final dateStr = _dateFormat.format(selectedDay);

    // Categories for this date: active + archived with entries
    final entryIds = (journalBloc.state.monthCategoryMarkers[dateStr] ?? {})
        .keys
        .toSet();
    final categories = <CategoryConfig>[];
    for (final cat in categoryState.categories) {
      if (!cat.isArchived || entryIds.contains(cat.id)) {
        categories.add(cat);
      }
    }
    categories.sort((a, b) => a.order.compareTo(b.order));
    if (categories.isEmpty) return;

    final screenSize = MediaQuery.of(context).size;
    const bubbleRadius = 24.0;

    // Anchor on the cell center, always (#190); screen center fallback
    // when no cell could be resolved.
    final effectiveAnchor =
        anchor ?? Offset(screenSize.width / 2, screenSize.height / 2);

    final layout = resolveMenuLayout(
      categoryCount: categories.length,
      center: effectiveAnchor,
      screen: screenSize,
      bubbleRadius: bubbleRadius,
    );
    final radius = layout.radius;
    final window = layout.window;
    final boxSize = 2 * (radius + bubbleRadius);

    // Follow the cell, don't pin to open-time coordinates: keyboard insets
    // or scroll settling shift the calendar while the menu stays open
    // (#158), leaving a pinned menu floating off the cell. Falls back to
    // the static anchor when the day has no laid-out cell (outside days
    // in week formats skip the custom builders).
    final cellLink = _dayCellCenter(selectedDay) != null
        ? _dayCellLink(selectedDay)
        : null;

    // A dialog route instead of a raw OverlayEntry: the barrier handles
    // backdrop dismissal and the navigator handles the back gesture
    // natively (#158) — a PopScope inside an OverlayEntry never registers
    // with any ModalRoute and silently does nothing.
    final route = RawDialogRoute<void>(
      barrierColor: Colors.black54,
      barrierDismissible: true,
      barrierLabel: 'Dismiss category menu',
      transitionDuration: Duration.zero, // bubbles animate themselves
      pageBuilder: (routeContext, _, _) => Stack(
        children: [
          Positioned(
            left: cellLink != null ? 0 : effectiveAnchor.dx - boxSize / 2,
            top: cellLink != null ? 0 : effectiveAnchor.dy - boxSize / 2,
            child: _FollowCell(
              link: cellLink,
              // Live checkmarks (#158): rebuild badges when markers change
              // instead of reading them once at open.
              child: BlocBuilder<JournalBloc, JournalState>(
                bloc: journalBloc,
                buildWhen: (prev, curr) =>
                    prev.monthCategoryMarkers != curr.monthCategoryMarkers,
                builder: (_, state) => SizedBox(
                  width: boxSize,
                  height: boxSize,
                  child: CategoryRadialMenu(
                    categories: categories,
                    filledCounts: Map<String, int>.from(
                      state.monthCategoryMarkers[dateStr] ?? {},
                    ),
                    radius: radius,
                    window: window,
                    onCategoryTap: (category) {
                      _dismissRadialMenu();
                      if (category.isArchived) {
                        // Archived categories never render in the day view —
                        // Category detail is the only surface that shows them.
                        if (context.mounted) {
                          Navigator.pushNamed(
                            context,
                            '/category-detail',
                            arguments: category.id,
                          );
                        }
                        return;
                      }
                      // #256: bubbles browse — day view for the MENU's date,
                      // tapped category first. Re-assert the date against any
                      // selectedDate drift while the menu was open (the same
                      // concern the retired #158 stay-open test pinned).
                      journalBloc.add(SelectDate(selectedDay));
                      if (context.mounted) {
                        Navigator.pushNamed(
                          context,
                          '/daily-journal',
                          arguments: category.id,
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
          ),
        ],
      ),
    );

    _radialMenuRoute = route;
    Navigator.of(context).push(route).whenComplete(() {
      // Cleared on any dismissal path (barrier, back, programmatic).
      if (_radialMenuRoute == route) _radialMenuRoute = null;
    });
  }

  void _startTodayCall(BuildContext context) {
    // A FAB/nudge call is explicitly a TODAY capture: reset any stale
    // selected date so the call bloc's journalDate wiring (#252) picks up
    // today. The radial mic deliberately skips this — its cell tap already
    // selected the target date.
    final today = DateTime.now();
    context.read<JournalBloc>().add(SelectDate(today));
    // Pass the date explicitly too: the SelectDate above is processed
    // asynchronously and can lose the race with the call screen's bloc
    // construction (#266 review).
    Navigator.pushNamed(context, '/voice-call', arguments: today);
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
  final Set<String> filledCategoryIds;
  final List<CategoryConfig> categories;
  final DateTime date;
  final bool isToday;
  final int currentStreak;
  final void Function(String categoryId)? onCategoryTap;
  final VoidCallback? onBodyTap;
  final VoidCallback? onGoToToday;

  const _ProgressCard({
    required this.filledCategoryIds,
    required this.categories,
    required this.date,
    required this.isToday,
    this.currentStreak = 0,
    this.onCategoryTap,
    this.onBodyTap,
    this.onGoToToday,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        child: InkWell(
          onTap: onBodyTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // container:true carves the title into its own a11y node
                    // (the card-level 'Progress N of M' label otherwise
                    // swallows it) — flows tap the title to open the day
                    // view, clear of the category dots (#256).
                    Semantics(
                      container: true,
                      child: Text(
                        isToday
                            ? "Today's Progress"
                            : '${DateFormat('MMM d').format(date)} Progress',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!isToday) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Go to today',
                        child: SizedBox(
                          height: 26,
                          child: TextButton.icon(
                            onPressed: onGoToToday,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              visualDensity: VisualDensity.compact,
                              // The 26px SizedBox otherwise fights the
                              // button's 36px default minimum (#268 review).
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.today_rounded, size: 14),
                            label: const Text(
                              'Today',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ],
                    // The streak is a today-fact; a past date's card showing
                    // it would lie.
                    if (isToday && currentStreak > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.15),
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

/// Wraps the radial menu in a [CompositedTransformFollower] when a cell
/// link is available so the open menu tracks its cell through layout
/// shifts; passes the child through untouched on the static-anchor
/// fallback path.
class _FollowCell extends StatelessWidget {
  final LayerLink? link;
  final Widget child;

  const _FollowCell({required this.link, required this.child});

  @override
  Widget build(BuildContext context) {
    final cellLink = link;
    if (cellLink == null) return child;
    return CompositedTransformFollower(
      link: cellLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.center,
      followerAnchor: Alignment.center,
      child: child,
    );
  }
}
