import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class JDoodleUsageWidget extends StatefulWidget {
  const JDoodleUsageWidget({Key? key}) : super(key: key);

  @override
  State<JDoodleUsageWidget> createState() => _JDoodleUsageWidgetState();
}

class _JDoodleUsageWidgetState extends State<JDoodleUsageWidget> {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  Map<String, dynamic>? _usageStats;
  bool _isLoading = false;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _loadUsageStats();
  }

  Future<void> _loadUsageStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result =
          await _functions.httpsCallable('getJDoodleUsageStats').call();
      setState(() {
        _usageStats = result.data as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading usage stats: $e')),
        );
      }
    }
  }

  Future<void> _resetUsage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Usage Counters'),
        content: const Text(
            'Are you sure you want to reset all JDoodle usage counters? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isResetting = true;
    });

    try {
      await _functions.httpsCallable('resetJDoodleUsage').call();
      await _loadUsageStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usage counters reset successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting usage: $e')),
        );
      }
    } finally {
      setState(() {
        _isResetting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'JDoodle Usage Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _isLoading ? null : _loadUsageStats,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                    IconButton(
                      onPressed: _isResetting ? null : _resetUsage,
                      icon: _isResetting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore),
                      tooltip: 'Reset Usage',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_usageStats == null)
              const Center(
                child: Text('No usage data available'),
              )
            else
              Column(
                children: [
                  _buildUsageCard(),
                  const SizedBox(height: 16),
                  _buildLimitsCard(),
                  const SizedBox(height: 16),
                  _buildCacheCard(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard() {
    final dailyUsage = _usageStats!['dailyUsage'] as Map<String, dynamic>;
    final recentRequests =
        _usageStats!['recentRequests'] as Map<String, dynamic>;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Usage',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Active Users: ${dailyUsage.length}'),
            Text('Recent Requests: ${recentRequests.length}'),
            const SizedBox(height: 8),
            if (dailyUsage.isNotEmpty) ...[
              const Text(
                'User Daily Usage:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...dailyUsage.entries.take(5).map((entry) {
                final usage = entry.value as Map<String, dynamic>;
                return Text('• ${entry.key}: ${usage['count']} requests');
              }),
              if (dailyUsage.length > 5)
                Text('... and ${dailyUsage.length - 5} more users'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLimitsCard() {
    final limits = _usageStats!['limits'] as Map<String, dynamic>;

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rate Limits',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Daily Limit: ${limits['daily']} requests'),
            Text('Minute Limit: ${limits['minute']} requests'),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheCard() {
    final cacheSize = _usageStats!['cacheSize'] as int;

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cache Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Cached Results: $cacheSize'),
            Text('Cache Status: ${cacheSize > 0 ? 'Active' : 'Empty'}'),
          ],
        ),
      ),
    );
  }
}
