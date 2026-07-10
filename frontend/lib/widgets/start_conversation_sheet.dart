import 'package:flutter/material.dart';
import '../services/bonder_service.dart';

Future<void> showStartConversationSheet(
  BuildContext context, {
  required void Function(BonderItem friend) onFriendSelected,
  List<BonderItem>? friends,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return _StartConversationSheet(
        initialFriends: friends,
        onFriendSelected: (friend) {
          Navigator.pop(sheetContext);
          onFriendSelected(friend);
        },
      );
    },
  );
}

class _StartConversationSheet extends StatefulWidget {
  final List<BonderItem>? initialFriends;
  final void Function(BonderItem friend) onFriendSelected;

  const _StartConversationSheet({
    required this.initialFriends,
    required this.onFriendSelected,
  });

  @override
  State<_StartConversationSheet> createState() =>
      _StartConversationSheetState();
}

class _StartConversationSheetState extends State<_StartConversationSheet> {
  final BonderService _bonderService = BonderService();
  final TextEditingController _searchController = TextEditingController();

  List<BonderItem> _friends = [];
  List<BonderItem> _filteredFriends = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterFriends);
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    if (widget.initialFriends != null) {
      setState(() {
        _friends = List.from(widget.initialFriends!);
        _filteredFriends = List.from(_friends);
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final friends = await _bonderService.getFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _filteredFriends = List.from(_friends);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _filterFriends() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredFriends = _friends
          .where((friend) => friend.name.toLowerCase().contains(query))
          .toList();
    });
  }

  Widget _buildAvatar(BonderItem friend) {
    final avatarUrl = friend.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF4675B8),
      child: Text(
        friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Start a conversation',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a friend to message',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search friends...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.red.shade400,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadFriends,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _filteredFriends.isEmpty
                            ? Center(
                                child: Text(
                                  _searchController.text.trim().isEmpty
                                      ? 'No friends yet.'
                                      : 'No matching friends found.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _filteredFriends.length,
                                separatorBuilder: (_, __) =>
                                    Divider(color: Colors.grey.shade200),
                                itemBuilder: (context, index) {
                                  final friend = _filteredFriends[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: _buildAvatar(friend),
                                    title: Text(
                                      friend.name,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      friend.lastMsg,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.chat_bubble_outline,
                                      color: Color(0xFF4675B8),
                                    ),
                                    onTap: () =>
                                        widget.onFriendSelected(friend),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
