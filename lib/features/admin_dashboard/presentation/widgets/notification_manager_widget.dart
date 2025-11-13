import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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
  
  // المحافظات بالعربية (نفس الأسماء في قاعدة البيانات)
  final List<String> _governorates = [
    'القاهرة',
    'الإسكندرية',
    'الجيزة',
    'القليوبية',
    'الدقهلية',
    'الشرقية',
    'الغربية',
    'المنوفية',
    'البحيرة',
    'كفر الشيخ',
    'دمياط',
    'بورسعيد',
    'الإسماعيلية',
    'السويس',
    'المنيا',
    'بني سويف',
    'الفيوم',
    'أسيوط',
    'سوهاج',
    'قنا',
    'الأقصر',
    'أسوان',
    'البحر الأحمر',
    'الوادي الجديد',
    'مطروح',
    'شمال سيناء',
    'جنوب سيناء',
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

      // Send via Cloudflare Worker (Production Ready!)
      // ✅ مهم: لازم يكون /send-custom-notification في النهاية!
      final serverUrl = 'https://notification-webhook.ah3181997-1e7.workers.dev/send-custom-notification';
      
      // للاختبار المحلي: استخدم localhost
      // final serverUrl = 'http://localhost:3000/send-custom-notification';
      
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': _titleController.text,
          'message': _messageController.text,
          'tokens': tokens,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send notification: ${response.body}');
      }

      final result = jsonDecode(response.body);
      final sent = result['success'] ?? 0;
      final failed = result['failure'] ?? 0;

      // Save to database for history
      final supabase = Supabase.instance.client;
      await supabase.from('notifications_sent').insert({
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

      _showSuccess('Notification sent! ✅ $sent sent, ❌ $failed failed');
      
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
      // Step 1: Get user IDs based on target
      List<String> userIds = [];
      
      if (_targetType == 'all') {
        // Get all users
        final usersResult = await supabase
            .from('users')
            .select('id');
        userIds = (usersResult as List)
            .map((user) => user['id'] as String)
            .toList();
      } else if (_targetType == 'role') {
        // Get users by role
        final usersResult = await supabase
            .from('users')
            .select('id')
            .eq('role', _selectedRole!);
        userIds = (usersResult as List)
            .map((user) => user['id'] as String)
            .toList();
      } else if (_targetType == 'governorate') {
        // Get users by governorate
        // ✅ governorates هو JSONB array
        print('🔍 Searching for governorate: $_selectedGovernorate');
        
        // جلب كل المستخدمين وفلترتهم في Flutter
        // (لأن JSONB contains قد لا يعمل بشكل صحيح)
        final allUsersResult = await supabase
            .from('users')
            .select('id, governorates');
        
        print('📊 Total users: ${(allUsersResult as List).length}');
        
        // فلترة المستخدمين الذين عندهم المحافظة المختارة
        final filteredUsers = (allUsersResult as List).where((user) {
          final governorates = user['governorates'];
          if (governorates is List) {
            return governorates.contains(_selectedGovernorate);
          }
          return false;
        }).toList();
        
        print('📊 Filtered users: ${filteredUsers.length}');
        if (filteredUsers.isNotEmpty) {
          print('📝 Sample: ${filteredUsers[0]}');
        }
        
        userIds = filteredUsers
            .map((user) => user['id'] as String)
            .toList();
      }
      
      if (userIds.isEmpty) {
        return [];
      }
      
      // Step 2: Get FCM tokens from user_tokens table
      // ✅ Get only the latest token per user to avoid duplicates
      final tokensResult = await supabase
          .from('user_tokens')
          .select('user_id, token, updated_at')
          .inFilter('user_id', userIds)
          .order('updated_at', ascending: false);
      
      // ✅ Remove duplicates: keep only the latest token per user
      final Map<String, String> uniqueTokens = {};
      for (var row in tokensResult as List) {
        final userId = row['user_id'] as String;
        final token = row['token'] as String?;
        
        if (token != null && token.isNotEmpty && !uniqueTokens.containsKey(userId)) {
          uniqueTokens[userId] = token;
        }
      }
      
      return uniqueTokens.values.toList();
    } catch (e) {
      print('Error getting tokens: $e');
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
