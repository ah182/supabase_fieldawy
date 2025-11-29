import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/leaderboard/application/leaderboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReferralEntryDialog extends HookConsumerWidget {
  const ReferralEntryDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralCodeController = useTextEditingController();
    final isLoading = useState(false);
    final theme = Theme.of(context);

    Future<void> submitReferralCode() async {
      if (referralCodeController.text.trim().isEmpty) return;

      isLoading.value = true;

      try {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser == null) {
          throw Exception('User not logged in');
        }

        await Supabase.instance.client.functions.invoke('handle-referral', body: {
          'referral_code': referralCodeController.text.trim(),
          'invited_id': currentUser.id,
        });

        // Invalidate providers to refresh the UI
        ref.invalidate(wasInvitedProvider);
        ref.invalidate(userDataProvider);
        ref.invalidate(leaderboardProvider);

        if (context.mounted) {
          Navigator.of(context).pop(); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Referral code applied successfully!')),
          );
        }

      } on FunctionException catch (e) {
        final details = e.details;
        if (context.mounted) {
          if (details is Map && details['error'] == 'You cannot refer yourself') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You cannot use your own referral code.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid or expired referral code.')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Enter Referral Code',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter a referral code to earn bonus points!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: referralCodeController,
            decoration: InputDecoration(
              hintText: 'Referral Code',
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.card_giftcard),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isLoading.value ? null : submitReferralCode,
          child: isLoading.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Apply'),
        ),
      ],
    );
  }
}
