import 'package:flutter/material.dart';

import '../api_service.dart';
import '../data/exercise_catalog.dart';
import '../theme/app_theme.dart';

// Session cache of the user's own exercise history, so reopening the picker
// paints the merged list immediately. A fresh fetch still runs on every open
// (in the background) to pick up newly logged / AI-session exercises.
List<String> _historyCache = const [];

/// Selection-only exercise picker: a bottom sheet listing the curated catalog
/// merged with the user's own history. The search box only FILTERS the list —
/// the returned value always comes from it, so typos can't reach the log.
/// Opens instantly on the const catalog; history merges in when fetched.
Future<String?> showExercisePicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _ExercisePickerSheet(),
  );
}

List<String> _mergedList(List<String> history) {
  final seen = <String>{for (final e in kExerciseCatalog) e.toLowerCase()};
  return [
    ...kExerciseCatalog,
    for (final e in history)
      if (seen.add(e.toLowerCase())) e,
  ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  late List<String> _all = _mergedList(_historyCache);
  String _query = '';

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    final list = await getUserExercises();
    if (list.isEmpty) return;
    _historyCache = list;
    if (mounted) setState(() => _all = _mergedList(list));
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? _all
        : _all.where((e) => e.toLowerCase().contains(q)).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text('CHOOSE EXERCISE', style: kLabelSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search exercises…',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        'No matching exercise',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                      itemCount: matches.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        title: Text(
                          matches[i],
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, matches[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
