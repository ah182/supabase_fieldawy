import 'package:flutter/material.dart';

/// Bulk Operations Mixin
/// Provides selection and bulk action capabilities for any list
/// 
/// Usage:
/// ```dart
/// class MyScreen extends StatefulWidget with BulkOperationsMixin<User> {
///   // Your code
/// }
/// ```
mixin BulkOperationsMixin<T> {
  // Selected items
  final Set<String> selectedIds = {};
  
  // Selection state
  bool get hasSelection => selectedIds.isNotEmpty;
  bool get isAllSelected => selectedIds.length == totalItems;
  int get selectedCount => selectedIds.length;
  int get totalItems => 0; // Override this
  
  /// Toggle selection for an item
  void toggleSelection(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
  }
  
  /// Check if item is selected
  bool isSelected(String id) => selectedIds.contains(id);
  
  /// Select all items
  void selectAll(List<String> allIds) {
    selectedIds.clear();
    selectedIds.addAll(allIds);
  }
  
  /// Clear selection
  void clearSelection() {
    selectedIds.clear();
  }
  
  /// Toggle select all
  void toggleSelectAll(List<String> allIds) {
    if (isAllSelected) {
      clearSelection();
    } else {
      selectAll(allIds);
    }
  }
  
  /// Show bulk actions toolbar
  Widget buildBulkActionsToolbar({
    required BuildContext context,
    required VoidCallback onApprove,
    required VoidCallback onReject,
    required VoidCallback onDelete,
    bool showApprove = true,
    bool showReject = true,
    bool showDelete = true,
  }) {
    if (!hasSelection) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          // Selection info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$selectedCount selected',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Actions
          if (showApprove)
            _ActionButton(
              icon: Icons.check_circle,
              label: 'Approve',
              color: Colors.green,
              onPressed: () => _confirmAction(
                context: context,
                title: 'Approve Selected',
                message: 'Are you sure you want to approve $selectedCount items?',
                confirmText: 'Approve',
                onConfirm: onApprove,
              ),
            ),
          
          if (showReject)
            _ActionButton(
              icon: Icons.cancel,
              label: 'Reject',
              color: Colors.orange,
              onPressed: () => _confirmAction(
                context: context,
                title: 'Reject Selected',
                message: 'Are you sure you want to reject $selectedCount items?',
                confirmText: 'Reject',
                onConfirm: onReject,
              ),
            ),
          
          if (showDelete)
            _ActionButton(
              icon: Icons.delete,
              label: 'Delete',
              color: Colors.red,
              onPressed: () => _confirmAction(
                context: context,
                title: 'Delete Selected',
                message: 'Are you sure you want to delete $selectedCount items? This cannot be undone!',
                confirmText: 'Delete',
                onConfirm: onDelete,
                isDangerous: true,
              ),
            ),
          
          const Spacer(),
          
          // Clear selection
          TextButton.icon(
            onPressed: clearSelection,
            icon: const Icon(Icons.close),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }
  
  /// Confirm action dialog
  void _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
    bool isDangerous = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isDangerous ? Icons.warning : Icons.info,
              color: isDangerous ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDangerous ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
