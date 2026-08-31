import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

/// Short AI-generated interpretation of the gym's current stats,
/// backed by the Laravel /api/ai/dashboard-summary route (Groq).
class AiInsightCard extends StatefulWidget {
  const AiInsightCard({super.key});

  @override
  State<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<AiInsightCard> {
  static const String _baseUrl = 'http://127.0.0.1:8000/api';

  String? _summary;
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
      final res = await http.get(Uri.parse('$_baseUrl/ai/dashboard-summary'));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }
      setState(() {
        _summary = data['summary'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load AI insight';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: AppTheme.cardDecoration(context, accent: AppColors.gold),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.goldBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, size: 17, color: AppColors.gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _loading
                ? Text("Analyzing today's data...",
                    style: TextStyle(color: AppTheme.textMuted(context)))
                : _error != null
                    ? Text(_error!, style: const TextStyle(color: AppColors.danger))
                    : Text(_summary ?? '',
                        style: TextStyle(fontSize: 14, height: 1.5, color: AppTheme.heading(context))),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh insight',
          ),
        ],
      ),
    );
  }
}