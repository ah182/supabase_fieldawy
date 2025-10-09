import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/services/notification_preferences_service.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  bool _isLoading = true;
  bool _priceActionEnabled = true;
  bool _expireSoonEnabled = true;
  bool _offersEnabled = true;
  bool _surgicalToolsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await NotificationPreferencesService.getPreferences();
      setState(() {
        _priceActionEnabled = prefs['price_action'] ?? true;
        _expireSoonEnabled = prefs['expire_soon'] ?? true;
        _offersEnabled = prefs['offers'] ?? true;
        _surgicalToolsEnabled = prefs['surgical_tools'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الإعدادات: $e')),
        );
      }
    }
  }

  Future<void> _updatePreference(String type, bool value) async {
    try {
      await NotificationPreferencesService.updatePreference(type, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حفظ الإعدادات: $e')),
        );
      }
      // Revert the change
      await _loadPreferences();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('notificationSettings'.tr()),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  'chooseNotificationTypes'.tr(),
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Price Action Toggle
                _buildNotificationToggle(
                  icon: Icons.monetization_on_rounded,
                  iconColor: Colors.green,
                  title: 'priceUpdates'.tr(),
                  subtitle: 'receivePriceUpdateNotifications'.tr(),
                  value: _priceActionEnabled,
                  onChanged: (value) {
                    setState(() => _priceActionEnabled = value);
                    _updatePreference('price_action', value);
                  },
                ),

                const SizedBox(height: 12),

                // Expire Soon Toggle
                _buildNotificationToggle(
                  icon: Icons.warning_rounded,
                  iconColor: Colors.orange,
                  title: 'expiringProducts'.tr(),
                  subtitle: 'receiveExpiringProductNotifications'.tr(),
                  value: _expireSoonEnabled,
                  onChanged: (value) {
                    setState(() => _expireSoonEnabled = value);
                    _updatePreference('expire_soon', value);
                  },
                ),

                const SizedBox(height: 12),

                // Offers Toggle
                _buildNotificationToggle(
                  icon: Icons.local_offer_rounded,
                  iconColor: Colors.red,
                  title: 'offers'.tr(),
                  subtitle: 'receiveOffersNotifications'.tr(),
                  value: _offersEnabled,
                  onChanged: (value) {
                    setState(() => _offersEnabled = value);
                    _updatePreference('offers', value);
                  },
                ),

                const SizedBox(height: 12),

                // Surgical Tools Toggle
                _buildNotificationToggle(
                  icon: Icons.medical_services_rounded,
                  iconColor: Colors.blue,
                  title: 'surgicalTools'.tr(),
                  subtitle: 'receiveSurgicalToolsNotifications'.tr(),
                  value: _surgicalToolsEnabled,
                  onChanged: (value) {
                    setState(() => _surgicalToolsEnabled = value);
                    _updatePreference('surgical_tools', value);
                  },
                ),

                const SizedBox(height: 24),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'notificationPreferencesInfo'.tr(),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNotificationToggle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}
