import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

// Temporary provider until offers_repository is updated
final offersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.from('offers').select().order('created_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

class OffersTrackerWidget extends ConsumerWidget {
  const OffersTrackerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offersProvider);

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
                    color: Colors.pink.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_offer,
                      color: Colors.pink.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Offers Tracker',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    ref.invalidate(offersProvider);
                  },
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Content
            offersAsync.when(
              loading: () => const SizedBox(
                height: 400,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SizedBox(
                height: 400,
                child: Center(child: Text('Error: ${err.toString()}')),
              ),
              data: (offers) {
                if (offers.isEmpty) {
                  return const SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_offer_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No offers available'),
                        ],
                      ),
                    ),
                  );
                }

                final now = DateTime.now();
                final activeOffers = offers.where((o) {
                  final expDate = o['expiration_date'];
                  if (expDate == null) return false;
                  final expirationDate = DateTime.parse(expDate.toString());
                  return expirationDate.isAfter(now);
                }).toList();
                
                final expiredOffers = offers.where((o) {
                  final expDate = o['expiration_date'];
                  if (expDate == null) return false;
                  final expirationDate = DateTime.parse(expDate.toString());
                  return expirationDate.isBefore(now);
                }).toList();
                
                final expiringSoon = activeOffers.where((o) {
                  final expDate = o['expiration_date'];
                  if (expDate == null) return false;
                  final expirationDate = DateTime.parse(expDate.toString());
                  return expirationDate.difference(now).inHours < 24;
                }).toList();

                return Column(
                  children: [
                    // Summary Stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Active Offers',
                            value: activeOffers.length.toString(),
                            icon: Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Expiring Soon',
                            value: expiringSoon.length.toString(),
                            icon: Icons.warning,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Expired',
                            value: expiredOffers.length.toString(),
                            icon: Icons.cancel,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Expiring Soon Alert
                    if (expiringSoon.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.orange.shade200, width: 2),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time,
                                color: Colors.orange.shade700, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${expiringSoon.length} offer(s) expiring within 24 hours!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                  Text(
                                    'Review and extend if needed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (expiringSoon.isNotEmpty) const SizedBox(height: 24),
                    // Offers List
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            tabs: [
                              Tab(
                                  text: 'Active (${activeOffers.length})',
                                  icon: const Icon(Icons.check_circle,
                                      size: 18)),
                              Tab(
                                  text: 'Expired (${expiredOffers.length})',
                                  icon: const Icon(Icons.cancel, size: 18)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 400,
                            child: TabBarView(
                              children: [
                                // Active Offers
                                activeOffers.isEmpty
                                    ? const Center(
                                        child: Text('No active offers'))
                                    : ListView.separated(
                                        itemCount: activeOffers.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(),
                                        itemBuilder: (context, index) {
                                          final offer = activeOffers[index];
                                          final expDate = offer['expiration_date'];
                                          final expirationDate = expDate != null 
                                              ? DateTime.parse(expDate.toString())
                                              : DateTime.now();
                                          final isExpiringSoon = expirationDate
                                              .difference(now)
                                              .inHours <
                                              24;
                                          return _OfferItem(
                                            offer: offer,
                                            isActive: true,
                                            isExpiringSoon: isExpiringSoon,
                                          );
                                        },
                                      ),
                                // Expired Offers
                                expiredOffers.isEmpty
                                    ? const Center(
                                        child: Text('No expired offers'))
                                    : ListView.separated(
                                        itemCount: expiredOffers.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(),
                                        itemBuilder: (context, index) {
                                          return _OfferItem(
                                            offer: expiredOffers[index],
                                            isActive: false,
                                            isExpiringSoon: false,
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OfferItem extends StatelessWidget {
  const _OfferItem({
    required this.offer,
    required this.isActive,
    required this.isExpiringSoon,
  });

  final offer;
  final bool isActive;
  final bool isExpiringSoon;

  @override
  Widget build(BuildContext context) {
    final timeRemaining = offer.expirationDate.difference(DateTime.now());
    final timeAgo = timeago.format(offer.expirationDate);

    return Card(
      elevation: isExpiringSoon ? 4 : 1,
      color: isExpiringSoon ? Colors.orange.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? (isExpiringSoon
                        ? Colors.orange.shade100
                        : Colors.green.shade100)
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isActive
                    ? (isExpiringSoon
                        ? Icons.access_time
                        : Icons.check_circle)
                    : Icons.cancel,
                color: isActive
                    ? (isExpiringSoon
                        ? Colors.orange.shade700
                        : Colors.green.shade700)
                    : Colors.red.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Offer details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (offer.description != null)
                    Text(
                      offer.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        offer.distributorName,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (offer.discount != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${offer.discount}% OFF',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Time remaining
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isActive) ...[
                  Text(
                    isExpiringSoon
                        ? '${timeRemaining.inHours}h left'
                        : '${timeRemaining.inDays}d left',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isExpiringSoon
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Expired',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
