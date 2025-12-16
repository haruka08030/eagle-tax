class Profile {
  final String id;
  final String? shopifyShopName;
  final String? shopifyAccessToken;
  final DateTime? createdAt;

  Profile({
    required this.id,
    this.shopifyShopName,
    this.shopifyAccessToken,
    this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    try {
      return Profile(
        id: json['id'] as String,
        shopifyShopName: json['shopify_shop_name'] as String?,
        shopifyAccessToken: json['shopify_access_token'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );
    } catch (e) {
      throw FormatException('Invalid JSON format for Profile: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shopify_shop_name': shopifyShopName,
      'shopify_access_token': shopifyAccessToken,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  bool get isShopifyConnected =>
      shopifyShopName != null &&
      shopifyShopName!.isNotEmpty &&
      shopifyAccessToken != null &&
      shopifyAccessToken!.isNotEmpty;

  @override
  String toString() {
    return 'Profile(id: $id, shopifyShopName: $shopifyShopName, isConnected: $isShopifyConnected)';
  }
}
