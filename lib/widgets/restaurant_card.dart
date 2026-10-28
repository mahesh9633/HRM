import 'dart:async';
import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';

class RestaurantCard extends StatefulWidget {
  final Restaurant restaurant;
  final double? userLat;
  final double? userLng;
  final VoidCallback onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.userLat,
    this.userLng,
    required this.onTap,
  });

  @override
  State<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<RestaurantCard> {
  late PageController _pageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;
  bool _isFavorite = false;

  // Matrix for greyscale filter on closed banners
  static const List<double> _greyscaleMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentBannerIndex);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _bannerTimer?.cancel();
    final bannerUrls = widget.restaurant.getFullBannerUrls();
    final bannersToDisplay =
        bannerUrls.isNotEmpty ? bannerUrls : [widget.restaurant.getFullLogoUrl()];

    if (bannersToDisplay.length > 1) {
      _bannerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!mounted || !_pageController.hasClients) return;
        final nextIndex = (_currentBannerIndex + 1) % bannersToDisplay.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void didUpdateWidget(RestaurantCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurant.id != widget.restaurant.id ||
        oldWidget.restaurant.banners != widget.restaurant.banners) {
      _currentBannerIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final isOpen = restaurant.isOpenNow();
    final bannerUrls = restaurant.getFullBannerUrls();
    final distText = restaurant.formattedDistance(widget.userLat, widget.userLng);
    final timeText = restaurant.estimatedTimeText(widget.userLat, widget.userLng);

    final addressOrPincode = restaurant.address.isNotEmpty
        ? restaurant.address
        : (restaurant.pincode.isNotEmpty ? 'Pincode: ${restaurant.pincode}' : '');

    final bannersToDisplay =
        bannerUrls.isNotEmpty ? bannerUrls : [restaurant.getFullLogoUrl()];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
        border: Border.all(color: AppTheme.chipUnselected),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Banner Carousel
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.cardCornerRadius),
                    ),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: bannersToDisplay.length,
                      onPageChanged: (index) {
                        setState(() => _currentBannerIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final bannerUrl = bannersToDisplay[index];
                        final imgWidget = _buildBannerImage(
                            bannerUrl, restaurant.getFullLogoUrl());

                        if (!isOpen) {
                          return ColorFiltered(
                            colorFilter:
                                const ColorFilter.matrix(_greyscaleMatrix),
                            child: imgWidget,
                          );
                        }
                        return imgWidget;
                      },
                    ),
                  ),
                ),

                // Dark Overlay for Closed Restaurants
                if (!isOpen)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppTheme.cardCornerRadius),
                        ),
                      ),
                    ),
                  ),

                // Gradient Overlay for text readability (Open state)
                if (isOpen)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppTheme.cardCornerRadius),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                // Heart / Favorite Icon
                Positioned(
                  top: 10,
                  left: 10,
                  child: InkWell(
                    onTap: () {
                      setState(() => _isFavorite = !_isFavorite);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color:
                            _isFavorite ? AppTheme.closedRed : AppTheme.textDark,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // Delivery Time Badge (Swiggy tab-style label on bottom-right of image for open restaurants)
                if (isOpen && timeText != null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x29000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeText,
                            style: const TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Container(
                            height: 2,
                            width: 24,
                            margin: const EdgeInsets.only(top: 2),
                            color: AppTheme.textDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Closed Overlay Text (Bottom Left of Image)
                if (!isOpen)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Opening soon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          restaurant.openingText(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Carousel Dots Indicator (If multiple banners and open)
                if (isOpen && bannersToDisplay.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(
                        bannersToDisplay.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentBannerIndex == index ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentBannerIndex == index
                                ? AppTheme.primary
                                : Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Bottom Section: Info Bar
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isOpen ? AppTheme.primary : AppTheme.textMuted,
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: _buildLogoImage(restaurant.getFullLogoUrl()),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name & Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                restaurant.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isOpen
                                      ? AppTheme.textDark
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildVegBadge(restaurant),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Rating + Address + Distance Row (e.g. "4.0 ★  •  Madanapalli Road, 2.0 km")
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? AppTheme.openGreen
                                    : AppTheme.textMuted,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    restaurant.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.star,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            if (addressOrPincode.isNotEmpty || distText != null) ...[
                              const SizedBox(width: 8),
                              const Text(
                                '•',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _buildAddressAndDistString(
                                      addressOrPincode, distText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Open Badge (Shown only for open restaurants)
                  if (isOpen) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.openGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.openGreen,
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.openGreen,
                        ),
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

  String _buildAddressAndDistString(String address, String? distText) {
    if (address.isNotEmpty && distText != null) {
      return '$address, $distText';
    } else if (address.isNotEmpty) {
      return address;
    } else if (distText != null) {
      return distText;
    }
    return '';
  }

  Widget _buildVegBadge(Restaurant restaurant) {
    final isVeg = restaurant.isVegetarian;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(
          color: isVeg ? AppTheme.openGreen : AppTheme.closedRed,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.circle,
        size: 7,
        color: isVeg ? AppTheme.openGreen : AppTheme.closedRed,
      ),
    );
  }

  Widget _buildBannerImage(String bannerUrl, String logoUrl) {
    if (bannerUrl.isEmpty) {
      return _buildFallbackBannerWidget(logoUrl);
    }

    return Image.network(
      bannerUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _buildFallbackBannerWidget(logoUrl),
    );
  }

  Widget _buildLogoImage(String logoUrl) {
    if (logoUrl.isEmpty) {
      return Container(
        color: AppTheme.primarySoft,
        child: const Center(
          child: Icon(Icons.storefront, color: AppTheme.primaryDark, size: 24),
        ),
      );
    }

    return Image.network(
      logoUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppTheme.primarySoft,
        child: const Center(
          child: Icon(Icons.storefront, color: AppTheme.primaryDark, size: 24),
        ),
      ),
    );
  }

  Widget _buildFallbackBannerWidget(String logoUrl) {
    return Container(
      color: AppTheme.primarySoft,
      child: Center(
        child: logoUrl.isNotEmpty
            ? Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: Image.network(
                    logoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.storefront,
                      color: AppTheme.primaryDark,
                      size: 30,
                    ),
                  ),
                ),
              )
            : const Icon(
                Icons.storefront,
                color: AppTheme.primaryDark,
                size: 40,
              ),
      ),
    );
  }
}
