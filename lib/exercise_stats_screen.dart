import 'package:flutter/material.dart';
import 'api_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'utils/fuzzy_search.dart';

class ExerciseStatsScreen extends StatefulWidget {
  const ExerciseStatsScreen({super.key});

  @override
  State<ExerciseStatsScreen> createState() => _ExerciseStatsScreenState();
}

class _ExerciseStatsScreenState extends State<ExerciseStatsScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _overlayLink = LayerLink();

  List<String> _allExercises = [];
  List<String> _suggestions = [];
  OverlayEntry? _overlay;

  Map<String, dynamic>? _stats;
  bool _loadingStats = false;
  String? _correctedTo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _removeOverlay();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final list = await getUserExercises();
    if (mounted) setState(() => _allExercises = list);
  }

  void _onTextChanged() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      _removeOverlay();
      return;
    }
    final q = query.toLowerCase();
    final scored = _allExercises.map((e) {
      final el = e.toLowerCase();
      final dist = levenshtein(q, el);
      final contains = el.contains(q) ? -1 : 0;
      return (e, dist + contains);
    }).toList()..sort((a, b) => a.$2.compareTo(b.$2));

    final top = scored.take(5).map((s) => s.$1).toList();
    setState(() => _suggestions = top);
    if (top.isNotEmpty) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        width: MediaQuery.of(context).size.width - 48,
        child: CompositedTransformFollower(
          link: _overlayLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, i) => InkWell(
                  onTap: () => _selectSuggestion(_suggestions[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      _suggestions[i],
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _selectSuggestion(String name) {
    _controller.text = name;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: name.length),
    );
    _removeOverlay();
    setState(() => _suggestions = []);
    _fetchStats(name, typed: _controller.text);
  }

  Future<void> _fetchStats(String name, {required String typed}) async {
    _removeOverlay();
    setState(() {
      _loadingStats = true;
      _stats = null;
      _error = null;
      _correctedTo = null;
    });

    String resolved = name;
    if (_allExercises.isNotEmpty) {
      final q = name.toLowerCase();
      final exactMatch = _allExercises.any((e) => e.toLowerCase() == q);
      if (!exactMatch) {
        final scored = _allExercises.map((e) {
          final el = e.toLowerCase();
          final dist = levenshtein(q, el);
          final contains = el.contains(q) ? -1 : 0;
          return (e, dist + contains);
        }).toList()..sort((a, b) => a.$2.compareTo(b.$2));
        if (scored.isNotEmpty && scored.first.$2 < 5) {
          resolved = scored.first.$1;
        }
      }
    }

    final data = await getExerciseStats(resolved);
    if (!mounted) return;

    if (data == null) {
      setState(() {
        _loadingStats = false;
        _error =
            'No data found for "$resolved". Try logging this exercise first.';
      });
      return;
    }

    setState(() {
      _loadingStats = false;
      _stats = data;
      _correctedTo = (resolved.toLowerCase() != typed.toLowerCase())
          ? resolved
          : null;
    });
  }

  void _onSubmitted(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _fetchStats(trimmed, typed: trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Exercise Stats',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      foreground: Paint()
                        ..shader = LinearGradient(
                          colors: [
                            AppColors.textPrimary,
                            AppColors.textSecondary,
                          ],
                        ).createShader(const Rect.fromLTWH(0, 0, 220, 40)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: CompositedTransformTarget(
                link: _overlayLink,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _onSubmitted,
                  decoration: InputDecoration(
                    hintText: 'Search exercises (e.g. "bench press")',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _stats = null;
                                _error = null;
                                _correctedTo = null;
                              });
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                children: [
                  if (_correctedTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_fix_high,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Showing results for: $_correctedTo',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_loadingStats)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    AppCard(
                      margin: EdgeInsets.zero,
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else if (_stats != null)
                    _buildStatsCard(_stats!)
                  else
                    _buildEmptyState(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(
              Icons.fitness_center,
              size: 56,
              color: AppColors.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for an exercise to see your stats',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Fuzzy search — even misspellings work',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> stats) {
    final exercise = stats['exercise'] as String? ?? '';
    final lastWeight = stats['last_weight'];
    final lastReps = stats['last_reps'];
    final lastSets = stats['last_sets'];
    final maxWeight = stats['max_weight'];
    final maxVolume = stats['max_volume'];
    final totalSessions = stats['total_sessions'] as int? ?? 0;

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalSessions session${totalSessions == 1 ? '' : 's'} logged',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Last Session',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statChip('Weight', lastWeight != null ? '${lastWeight}kg' : '—'),
              const SizedBox(width: 10),
              _statChip('Sets', lastSets?.toString() ?? '—'),
              const SizedBox(width: 10),
              _statChip('Reps', lastReps?.toString() ?? '—'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Personal Records',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statChip(
                'Max Weight',
                maxWeight != null ? '${maxWeight}kg' : '—',
                accent: true,
              ),
              const SizedBox(width: 10),
              _statChip(
                'Max Volume',
                maxVolume != null ? '${maxVolume.toStringAsFixed(0)}kg' : '—',
                accent: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, {bool accent = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.accent.withValues(alpha: 0.08)
              : AppColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accent
                ? AppColors.accent.withValues(alpha: 0.25)
                : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: accent ? AppColors.accent : AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
