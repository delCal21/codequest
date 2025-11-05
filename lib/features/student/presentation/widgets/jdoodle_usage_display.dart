import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JDoodleUsageDisplay extends StatefulWidget {
  const JDoodleUsageDisplay({Key? key}) : super(key: key);

  @override
  State<JDoodleUsageDisplay> createState() => _JDoodleUsageDisplayState();
}

class _JDoodleUsageDisplayState extends State<JDoodleUsageDisplay> {
  Map<String, dynamic>? _usageStats;
  bool _isLoading = false;

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
      // This is a simplified version that reads from local storage
      // In a real implementation, you might want to get this from your backend
      final prefs = await SharedPreferences.getInstance();
      final dailyCount = prefs.getInt('jdoodle_daily_count') ?? 0;
      final lastRequestDate = prefs.getString('jdoodle_last_request_date');

      final now = DateTime.now();
      final lastDate =
          lastRequestDate != null ? DateTime.parse(lastRequestDate) : null;

      // Reset daily count if it's a new day
      if (lastDate == null || now.difference(lastDate).inDays >= 1) {
        await prefs.setInt('jdoodle_daily_count', 0);
        await prefs.setString(
            'jdoodle_last_request_date', now.toIso8601String());
      }

      setState(() {
        _usageStats = {
          'dailyRequests': dailyCount,
          'dailyLimit': 200, // This should match your JDoodle plan
          'remainingDaily': 200 - dailyCount,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.code, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Code Execution Usage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _loadUsageStats,
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: 'Refresh',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_usageStats != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildUsageBar(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_usageStats!['dailyRequests']} / ${_usageStats!['dailyLimit']} requests used today',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '${_usageStats!['remainingDaily']} requests remaining',
                style: TextStyle(
                  fontSize: 12,
                  color: _usageStats!['remainingDaily'] < 50
                      ? Colors.orange
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else
              const Text(
                'Loading usage statistics...',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageBar() {
    final used = _usageStats!['dailyRequests'] as int;
    final total = _usageStats!['dailyLimit'] as int;
    final percentage = total > 0 ? used / total : 0.0;

    Color barColor;
    if (percentage < 0.7) {
      barColor = Colors.green;
    } else if (percentage < 0.9) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
        ),
      ],
    );
  }
}
