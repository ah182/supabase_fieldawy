class DashboardStats {
  final int totalProducts;
  final int activeOffers;
  final int totalViews;
  final int totalOrders;
  final double monthlyGrowth;
  final double totalRevenue;
  final int pendingOrders;
  final int completedOrders;
  final double averageRating;
  final int totalCustomers;

  DashboardStats({
    required this.totalProducts,
    required this.activeOffers,
    required this.totalViews,
    required this.totalOrders,
    required this.monthlyGrowth,
    required this.totalRevenue,
    required this.pendingOrders,
    required this.completedOrders,
    required this.averageRating,
    required this.totalCustomers,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalProducts: json['total_products'] ?? 0,
      activeOffers: json['active_offers'] ?? 0,
      totalViews: json['total_views'] ?? 0,
      totalOrders: json['total_orders'] ?? 0,
      monthlyGrowth: (json['monthly_growth'] ?? 0.0).toDouble(),
      totalRevenue: (json['total_revenue'] ?? 0.0).toDouble(),
      pendingOrders: json['pending_orders'] ?? 0,
      completedOrders: json['completed_orders'] ?? 0,
      averageRating: (json['average_rating'] ?? 0.0).toDouble(),
      totalCustomers: json['total_customers'] ?? 0,
    );
  }

  // Default constructor for when there's no data
  factory DashboardStats.empty() {
    return DashboardStats(
      totalProducts: 0,
      activeOffers: 0,
      totalViews: 0,
      totalOrders: 0,
      monthlyGrowth: 0.0,
      totalRevenue: 0.0,
      pendingOrders: 0,
      completedOrders: 0,
      averageRating: 0.0,
      totalCustomers: 0,
    );
  }
}