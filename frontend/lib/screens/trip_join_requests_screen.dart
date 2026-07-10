import 'package:flutter/material.dart';
import '../services/feed_service.dart';

class TripJoinRequestsScreen extends StatefulWidget {
  final String tripId;
  final String tripTitle;

  const TripJoinRequestsScreen({
    super.key,
    required this.tripId,
    required this.tripTitle,
  });

  @override
  State<TripJoinRequestsScreen> createState() => _TripJoinRequestsScreenState();
}

class _TripJoinRequestsScreenState extends State<TripJoinRequestsScreen> {
  final _feedService = FeedService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _feedService.listJoinRequests(widget.tripId);
      setState(() {
        _requests = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _act(String requestId, bool approve) async {
    try {
      if (approve) {
        await _feedService.approveJoinRequest(widget.tripId, requestId);
      } else {
        await _feedService.rejectJoinRequest(widget.tripId, requestId);
      }
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Approved' : 'Rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Requests · ${widget.tripTitle}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _requests.isEmpty
                  ? const Center(child: Text('No pending requests.'))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        itemCount: _requests.length,
                        itemBuilder: (context, i) {
                          final r = _requests[i];
                          final user = (r['user'] as Map?) ?? {};
                          final name = (user['full_name'] ??
                                  user['username'] ??
                                  'User')
                              .toString();
                          final status = r['status']?.toString() ?? 'pending';
                          final pending = status == 'pending';
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF4675B8),
                                backgroundImage: (user['avatar_url'] != null &&
                                        user['avatar_url'].toString().isNotEmpty)
                                    ? NetworkImage(user['avatar_url'].toString())
                                    : null,
                                child: (user['avatar_url'] == null ||
                                        user['avatar_url'].toString().isEmpty)
                                    ? Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style:
                                            const TextStyle(color: Colors.white),
                                      )
                                    : null,
                              ),
                              title: Text(name),
                              subtitle: Text(
                                pending
                                    ? (r['message']?.toString().isNotEmpty == true
                                        ? r['message'].toString()
                                        : 'Wants to join your trip')
                                    : 'Status: $status',
                              ),
                              trailing: pending
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check,
                                              color: Colors.green),
                                          onPressed: () =>
                                              _act(r['id'].toString(), true),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _act(r['id'].toString(), false),
                                        ),
                                      ],
                                    )
                                  : Text(status,
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic)),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
