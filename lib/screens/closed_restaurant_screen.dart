import 'dart:async';
import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';
import 'webview_screen.dart';

class ClosedRestaurantScreen extends StatefulWidget {
  final Restaurant restaurant;
  final List<Restaurant>? allRestaurants;

  const ClosedRestaurantScreen({
    super.key,
    required this.restaurant,
    this.allRestaurants,
  });

  @override
  State<ClosedRestaurantScreen> createState() => _ClosedRestaurantScreenState();
}

class _ClosedRestaurantScreenState extends State<ClosedRestaurantScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  late Restaurant _restaurant;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restaurant = widget.restaurant;
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndNavigateIfOpen();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _checkAndNavigateIfOpen();
    });
  }

  void _checkAndNavigateIfOpen() {
    if (_hasNavigated || !mounted) return;

    if (_restaurant.isOpenNow()) {
      _hasNavigated = true;
      _timer?.cancel();

      final rawUrl = _restaurant.url.trim();
      if (rawUrl.isEmpty) return;

      final formattedUrl =
          (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))
              ? rawUrl
              : 'https://$rawUrl';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WebViewScreen(
            initialUrl: formattedUrl,
            selectedRestaurant: _restaurant,
            restaurants: widget.allRestaurants,
          ),
        ),
      );
      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _getHeadlineText() {
    return _restaurant.openingText();
  }

  void _onOpenRestaurantSelected(Restaurant restaurant) {
    final rawUrl = restaurant.url.trim();

    if (rawUrl.isEmpty) return;

    final formattedUrl =
        (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))
            ? rawUrl
            : 'https://$rawUrl';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          initialUrl: formattedUrl,
          selectedRestaurant: restaurant,
          restaurants: widget.allRestaurants,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otherOpenRestaurants = widget.allRestaurants
            ?.where((r) => r.id != _restaurant.id && r.isOpenNow())
            .toList() ??
        [];

    final logoUrl = _restaurant.getFullLogoUrl();
    final addressText = _restaurant.address.isNotEmpty
        ? _restaurant.address
        : (_restaurant.pincode.isNotEmpty
            ? 'Pincode: ${_restaurant.pincode}'
            : '');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Top Stack Section with Dark Header, White Card, and Tilted Badge
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        // 1. Dark Top Area with Rounded Bottom Corners
                        Container(
                          height: 200,
                          width: double.infinity,
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 8,
                            left: 12,
                            right: 16,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF18181A),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back,
                                    color: Colors.white, size: 24),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Spacer(),
                              if (logoUrl.isNotEmpty)
                                Container(
                                  width: 38,
                                  height: 38,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white24, width: 1),
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      logoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.storefront,
                                          color: Colors.white54,
                                          size: 20),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // 2. White Card Container (Overlapping Dark Top Area)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 110,
                            left: 16,
                            right: 16,
                          ),
                          child: Material(
                            color: Colors.white,
                            elevation: 6,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 42, 20, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Orange Headline Text (One line only)
                                  Text(
                                    _getHeadlineText(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryDark,
                                    ),
                                  ),

                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16),
                                    child: Divider(height: 1),
                                  ),

                                  // Restaurant Info Row
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _restaurant.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textDark,
                                              ),
                                            ),
                                            if (addressText.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                addressText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Right: Rating + Veg Badge
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.openGreen,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _restaurant.rating
                                                      .toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                const Icon(Icons.star,
                                                    size: 10,
                                                    color: Colors.white),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.all(1.5),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: _restaurant.isVegetarian
                                                    ? AppTheme.openGreen
                                                    : AppTheme.closedRed,
                                                width: 1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                            child: Icon(
                                              Icons.circle,
                                              size: 6,
                                              color: _restaurant.isVegetarian
                                                  ? AppTheme.openGreen
                                                  : AppTheme.closedRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 3. Tilted Orange Badge ("Opening SOON!")
                        Positioned(
                          top: 80,
                          child: Transform.rotate(
                            angle: -0.10, // ~ -6 degrees
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.primaryDark,
                                    AppTheme.primary
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                    width: 1.8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x3D000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Opening',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'SOON!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                      height: 1.05,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 4. "Other restaurants to order from" Section
                    if (otherOpenRestaurants.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Other restaurants to order from',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 185,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: otherOpenRestaurants.length,
                          itemBuilder: (context, index) {
                            final restaurant = otherOpenRestaurants[index];
                            return _buildOtherOpenCard(restaurant);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Small Portrait Card for Other Open Restaurants
  Widget _buildOtherOpenCard(Restaurant restaurant) {
    final bannerUrls = restaurant.getFullBannerUrls();
    final imgUrl =
        bannerUrls.isNotEmpty ? bannerUrls.first : restaurant.getFullLogoUrl();

    final addressText = restaurant.address.isNotEmpty
        ? restaurant.address
        : (restaurant.pincode.isNotEmpty ? 'Pincode: ${restaurant.pincode}' : '');

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.chipUnselected),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _onOpenRestaurantSelected(restaurant),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Heart Icon
            Stack(
              children: [
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                    child: imgUrl.isNotEmpty
                        ? Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.primarySoft,
                              child: const Icon(Icons.storefront,
                                  color: AppTheme.primaryDark),
                            ),
                          )
                        : Container(
                            color: AppTheme.primarySoft,
                            child: const Icon(Icons.storefront,
                                color: AppTheme.primaryDark),
                          ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      size: 14,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),

            // Text Info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Rating Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.openGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              restaurant.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.star,
                                size: 9, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (addressText.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      addressText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
