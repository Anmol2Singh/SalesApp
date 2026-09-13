import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/complaints_leaderboard_provider.dart';

class ComplaintsLeaderboardScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const ComplaintsLeaderboardScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<ComplaintsLeaderboardScreen> createState() => _ComplaintsLeaderboardScreenState();
}

class _ComplaintsLeaderboardScreenState extends ConsumerState<ComplaintsLeaderboardScreen> {
  String _sortBy = 'resolved'; // 'resolved', 'tat', 'rating'

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(complaintsLeaderboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF1E1B4B),
              title: const Text(
                'Service Technician Leaderboard',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(complaintsLeaderboardProvider),
                ),
              ],
            ),
      body: leaderboardAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.military_tech_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'No technician resolution records found.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          // Sort entries based on selection
          final sorted = List<TechnicianLeaderboardEntry>.from(entries);
          if (_sortBy == 'resolved') {
            sorted.sort((a, b) => b.resolvedCount.compareTo(a.resolvedCount));
          } else if (_sortBy == 'tat') {
            sorted.sort((a, b) => a.avgTatHours.compareTo(b.avgTatHours));
          } else if (_sortBy == 'rating') {
            sorted.sort((a, b) => b.rating.compareTo(a.rating));
          }

          final top1 = sorted.isNotEmpty ? sorted[0] : null;
          final top2 = sorted.length > 1 ? sorted[1] : null;
          final top3 = sorted.length > 2 ? sorted[2] : null;

          final totalResolved = entries.fold<int>(0, (sum, e) => sum + e.resolvedCount);
          final avgTat = entries.isNotEmpty
              ? (entries.fold<double>(0, (sum, e) => sum + e.avgTatHours) / entries.length)
              : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top KPI Bento Row
                _buildKpiRow(totalResolved, avgTat, entries.length),
                const SizedBox(height: 20),

                // Top 3 Podium
                if (top1 != null) ...[
                  const Text(
                    'Service Excellence Champions',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPodium(top1, top2, top3),
                  const SizedBox(height: 24),
                ],

                // Sort Filter Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'All Technicians (${sorted.length})',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Sort by:',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildSortChip('Resolved', 'resolved', Icons.check_circle_outline),
                          const SizedBox(width: 8),
                          _buildSortChip('Fastest TAT', 'tat', Icons.timer_outlined),
                          const SizedBox(width: 8),
                          _buildSortChip('Highest Rating', 'rating', Icons.star_outline),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Ranked List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = sorted[index];
                    return _buildTechnicianRow(item, index + 1);
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error loading leaderboard: $e')),
      ),
    );
  }

  Widget _buildSortChip(String label, String key, IconData icon) {
    final isSelected = _sortBy == key;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF1E1B4B),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      onSelected: (val) {
        if (val) setState(() => _sortBy = key);
      },
    );
  }

  Widget _buildKpiRow(int totalResolved, double avgTat, int totalTechs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final cardWidth = isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;

        final cards = [
          _buildKpiCard(
            title: 'Tickets Resolved',
            value: '$totalResolved',
            subtitle: 'Closed complaints',
            icon: Icons.task_alt,
            color: const Color(0xFF10B981),
            width: cardWidth,
          ),
          _buildKpiCard(
            title: 'Average Turnaround',
            value: '${avgTat.toStringAsFixed(1)}h',
            subtitle: 'Response to resolution',
            icon: Icons.speed,
            color: const Color(0xFF6366F1),
            width: cardWidth,
          ),
          _buildKpiCard(
            title: 'Active Tech Staff',
            value: '$totalTechs',
            subtitle: 'On-call field agents',
            icon: Icons.engineering,
            color: const Color(0xFFF59E0B),
            width: cardWidth,
          ),
        ];

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: cards,
          );
        } else {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: 10),
              cards[1],
              const SizedBox(height: 10),
              cards[2],
            ],
          );
        }
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(
    TechnicianLeaderboardEntry top1,
    TechnicianLeaderboardEntry? top2,
    TechnicianLeaderboardEntry? top3,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Rank 2 - Silver
          if (top2 != null)
            Expanded(
              child: _buildPodiumColumn(
                entry: top2,
                rank: 2,
                medalColor: const Color(0xFF94A3B8),
                pedestalHeight: 80,
                trophyIcon: Icons.military_tech,
              ),
            )
          else
            const Expanded(child: SizedBox()),

          // Rank 1 - Gold (Tallest)
          Expanded(
            child: _buildPodiumColumn(
              entry: top1,
              rank: 1,
              medalColor: const Color(0xFFF59E0B),
              pedestalHeight: 110,
              trophyIcon: Icons.emoji_events,
            ),
          ),

          // Rank 3 - Bronze
          if (top3 != null)
            Expanded(
              child: _buildPodiumColumn(
                entry: top3,
                rank: 3,
                medalColor: const Color(0xFFB45309),
                pedestalHeight: 65,
                trophyIcon: Icons.workspace_premium,
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required TechnicianLeaderboardEntry entry,
    required int rank,
    required Color medalColor,
    required double pedestalHeight,
    required IconData trophyIcon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            CircleAvatar(
              radius: rank == 1 ? 30 : 25,
              backgroundColor: medalColor.withValues(alpha: 0.2),
              child: Text(
                entry.name.isNotEmpty ? entry.name[0].toUpperCase() : 'T',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: rank == 1 ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: medalColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: medalColor, shape: BoxShape.circle),
              child: Icon(trophyIcon, color: Colors.white, size: rank == 1 ? 14 : 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          '${entry.resolvedCount} Resolved',
          style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: medalColor),
        ),
        Text(
          'TAT: ${entry.avgTatHours.toStringAsFixed(1)}h',
          style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Container(
          height: pedestalHeight,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: medalColor.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: rank == 1 ? 22 : 18,
                fontWeight: FontWeight.bold,
                color: medalColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicianRow(TechnicianLeaderboardEntry entry, int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank <= 3 ? const Color(0xFF1E1B4B) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: rank <= 3 ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.totalCount} Assigned • ${entry.inProgressCount} In Progress',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${entry.resolvedCount} Resolved',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 13, color: Colors.amber.shade700),
                  const SizedBox(width: 3),
                  Text(
                    entry.rating.toStringAsFixed(1),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TAT: ${entry.avgTatHours.toStringAsFixed(0)}h',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
