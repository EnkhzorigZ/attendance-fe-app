import 'package:attendance_fe_app/services/api_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final List<Map<String, dynamic>> _days = [];
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  bool _hasNext = true;
  bool _isLoading = false;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasNext) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final response = await apiRequest(
      endpoint: '/api/attendance/history/?page=$_page&page_size=20',
      method: HttpMethod.get,
      showError: true,
      context: context,
      useToken: true,
    );

    if (response != null && response is Map<String, dynamic>) {
      final results = (response['results'] as List?) ?? [];
      setState(() {
        _days.addAll(results.cast<Map<String, dynamic>>());
        _hasNext = response['has_next'] == true;
        if (_hasNext) _page++;
        _isLoading = false;
        _initialLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _initialLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    _page = 1;
    _hasNext = true;
    _days.clear();
    await _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: Colors.transparent,
        title: Text(
          "Түүх",
          style: theme.textTheme.titleMedium,
        ),
        centerTitle: true,
      ),
      body: _initialLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _days.isEmpty
              ? const Center(child: Text('Түүх олдсонгүй'))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _days.length + (_hasNext ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _days.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CupertinoActivityIndicator()),
                        );
                      }

                      final day = _days[index];
                      final date = day['date'] ?? '';
                      final records = (day['records'] as List?)
                              ?.cast<Map<String, dynamic>>() ??
                          [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              date,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...records.map((record) {
                            final checkIn = record['check_in_time'];
                            final checkOut = record['check_out_time'];
                            final status = record['status'] ?? '';

                            final inTime = checkIn != null
                                ? DateTime.parse(checkIn)
                                    .toLocal()
                                    .toString()
                                    .substring(11, 16)
                                : '-';
                            final outTime = checkOut != null
                                ? DateTime.parse(checkOut)
                                    .toLocal()
                                    .toString()
                                    .substring(11, 16)
                                : '-';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  Icons.access_time,
                                  color: status == 'ACTIVE'
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                title:
                                    Text('Ирсэн: $inTime  →  Явсан: $outTime'),
                                // subtitle: Text(status),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}
