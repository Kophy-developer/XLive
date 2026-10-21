import 'package:flutter/material.dart';

import '../../core/network/api_json.dart';
import '../../features/insights/insights_repository.dart';
import '../social/social_api_screens.dart';
import '../../core/network/api_friendly_messages.dart';

const _purple = Color(0xFF8A2DDC);
const _sky = Color(0xFF35D3FB);
const _black = Color(0xFF0A0A0A);
const _light = Color(0xFFF6F6F6);

class PostInsightsArgs {
  const PostInsightsArgs({required this.targetType, required this.targetId});

  final String targetType;
  final String targetId;
}

class PostInsightsScreen extends StatefulWidget {
  const PostInsightsScreen({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final String targetType;
  final String targetId;

  @override
  State<PostInsightsScreen> createState() => _PostInsightsScreenState();
}

class _PostInsightsScreenState extends State<PostInsightsScreen> {
  final _insightsRepo = InsightsRepository();
  Map<String, dynamic>? _metrics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _insightsRepo.getInsights(
        targetType: widget.targetType,
        targetId: widget.targetId,
      );
      if (!mounted) return;
      setState(() {
        _metrics = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyApiMessage(e);
      });
    }
  }

  int _metric(List<String> keys) {
    final map = _metrics;
    if (map == null) return 0;
    for (final key in keys) {
      if (map[key] != null) return ApiJson.intValue(map[key]);
    }
    final nested = ApiJson.map(map['metrics']) ?? ApiJson.map(map['stats']);
    if (nested != null) {
      for (final key in keys) {
        if (nested[key] != null) return ApiJson.intValue(nested[key]);
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.targetType == 'clip' ? 'Clip insights' : 'Video insights';
    return XLiveSubpage(
      title: label,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? _InsightsErrorBody(message: _error!, onRetry: _load)
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      _MetricCard(label: 'Views', value: _metric(['views', 'viewCount']), icon: Icons.visibility_outlined),
                      _MetricCard(label: 'Likes', value: _metric(['likes', 'likeCount']), icon: Icons.favorite_border_rounded),
                      _MetricCard(label: 'Comments', value: _metric(['comments', 'commentCount']), icon: Icons.chat_bubble_outline_rounded),
                      _MetricCard(label: 'Shares', value: _metric(['shares', 'shareCount']), icon: Icons.ios_share_rounded),
                    ],
                  ),
                ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _light,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A0A0A0A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _purple),
          const Spacer(),
          Text(
            _formatCount(value),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _black),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _InsightsErrorBody extends StatelessWidget {
  const _InsightsErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_outlined, size: 48, color: _sky),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
