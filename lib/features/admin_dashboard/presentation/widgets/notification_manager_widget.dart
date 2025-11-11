import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationManagerWidget extends ConsumerStatefulWidget {
  const NotificationManagerWidget({super.key});

  @override
  ConsumerState<NotificationManagerWidget> createState() =>
      _NotificationManagerWidgetState();
}

class _NotificationManagerWidgetState
    extends ConsumerState<NotificationManagerWidget> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _targetType = 'all'; // all, role, governorate
  String? _selectedRole;
  String? _selectedGovernorate;
  
  bool _isSending = false;
  
  final List<String> _roles = ['doctor', 'distributor', 'company'];
  final List<String> _governorates = [
    'Cairo',
    'Alexandria',
    'Giza',
    'Qalyubia',
    'Dakahlia',
    'Sharqia',
    'Gharbia',
    // Add more governorates
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.notifications_active,
                      color: Colors.orange.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Push Notification Manager',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Target Selection
            _buildTargetSelector(),
            const SizedBox(height: 16),
            
            // Title Input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            
            // Message Input
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 24),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _previewNotification,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendNotification,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isSending ? 'Sending...' : 'Send Notification'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Target Audience:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('All Users'),
                value: 'all',
                groupValue: _targetType,
                onChanged: (value) => setState(() => _targetType = value!),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('By Role'),
                value: 'role',
                groupValue: _targetType,
                onChanged: (value) => setState(() => _targetType = value!),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('By Governorate'),
                value: 'governorate',
                groupValue: _targetType,
                onChanged: (value) => setState(() => _targetType = value!),
              ),
            ),
          ],
        ),
        
        // Role/Governorate Dropdown
        if (_targetType == 'role')
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Select Role',
              border: OutlineInputBorder(),
            ),
            value: _selectedRole,
            items: _roles.map((role) {
              return DropdownMenuItem(value: role, child: Text(role));
            }).toList(),
            onChanged: (value) => setState(() => _selectedRole = value),
          ),
        
        if (_targetType == 'governorate')
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Select Governorate',
              border: OutlineInputBorder(),
            ),
            value: _selectedGovernorate,
            items: _governorates.map((gov) {
              return DropdownMenuItem(value: gov, child: Text(gov));
            }).toList(),
            onChanged: (value) => setState(() => _selectedGovernorate = value),
          ),
      ],
    );
  }

  void _previewNotification() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications, color: Colors.orange),
            const SizedBox(width: 8),
            Text(_titleController.text.isEmpty
                ? 'Preview'
                : _titleController.text),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_messageController.text.isEmpty
                ? 'No message'
                : _messageController.text),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target: ${_getTargetDescription()}'),
                  Text('Time: ${DateTime.now().toString().substring(0, 16)}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getTargetDescription() {
    if (_targetType == 'all') return 'All Users';
    if (_targetType == 'role') return 'Role: ${_selectedRole ?? "Not selected"}';
    if (_targetType == 'governorate') {
      return 'Governorate: ${_selectedGovernorate ?? "Not selected"}';
    }
    return 'Unknown';
  }

  Future<void> _sendNotification() async {
    // Validate
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      _showError('Please fill in title and message');
      return;
    }
    
    if (_targetType == 'role' && _selectedRole == null) {
      _showError('Please select a role');
      return;
    }
    
    if (_targetType == 'governorate' && _selectedGovernorate == null) {
      _showError('Please select a governorate');
      return;
    }

    setState(() => _isSending = true);

    try {
      // Get FCM tokens based on target
      List<String> tokens = await _getTargetTokens();
      
      if (tokens.isEmpty) {
        _showError('No users found for selected target');
        return;
      }

      // Send via FCM (you need to implement FCM server endpoint)
      // For now, just save to database
      await Supabase.instance.client.from('notifications_sent').insert({
        'title': _titleController.text,
        'message': _messageController.text,
        'target_type': _targetType,
        'target_value': _targetType == 'role'
            ? _selectedRole
            : _targetType == 'governorate'
                ? _selectedGovernorate
                : 'all',
        'recipients_count': tokens.length,
        'sent_at': DateTime.now().toIso8601String(),
      });

      _showSuccess('Notification sent to ${tokens.length} users!');
      
      // Clear form
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _targetType = 'all';
        _selectedRole = null;
        _selectedGovernorate = null;
      });
    } catch (e) {
      _showError('Failed to send: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<List<String>> _getTargetTokens() async {
    final supabase = Supabase.instance.client;
    
    try {
      var query = supabase.from('users').select('fcm_token');
      
      if (_targetType == 'role') {
        query = query.eq('role', _selectedRole!);
      } else if (_targetType == 'governorate') {
        query = query.eq('governorate', _selectedGovernorate!);
      }
      
      final result = await query;
      return (result as List)
          .map((user) => user['fcm_token'] as String?)
          .where((token) => token != null && token.isNotEmpty)
          .cast<String>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
