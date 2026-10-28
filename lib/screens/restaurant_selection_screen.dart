// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import '../models/restaurant.dart';
// import '../repositories/restaurant_repository.dart';
// import '../services/location_service.dart';
// import '../theme/app_theme.dart';
// import '../widgets/restaurant_card.dart';
// import '../widgets/restaurant_skeleton.dart';
// import 'closed_restaurant_screen.dart';
// import 'contact_us_screen.dart';
// import 'location_picker_screen.dart';
// import 'webview_screen.dart';
//
// /// Keeps the search bar pinned at the top of the screen once the orange
// /// header has scrolled away. While pinned (content scrolling underneath)
// /// it gets the orange colour, so it looks like the new app bar.
// class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
//   final Widget child;
//   final double height;
//   final Color pinnedColor;
//
//   _SearchHeaderDelegate({
//     required this.child,
//     required this.height,
//     required this.pinnedColor,
//   });
//
//   @override
//   double get minExtent => height;
//
//   @override
//   double get maxExtent => height;
//
//   @override
//   Widget build(
//       BuildContext context,
//       double shrinkOffset,
//       bool overlapsContent,
//       ) {
//     return Container(
//       height: height,
//       color: overlapsContent ? pinnedColor : Colors.white,
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
//       child: child,
//     );
//   }
//
//   @override
//   bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) => true;
// }
//
// class RestaurantSelectionScreen extends StatefulWidget {
//   const RestaurantSelectionScreen({super.key});
//
//   @override
//   State<RestaurantSelectionScreen> createState() =>
//       _RestaurantSelectionScreenState();
// }
//
// class _RestaurantSelectionScreenState extends State<RestaurantSelectionScreen>
//     with WidgetsBindingObserver {
//   Timer? _statusUpdateTimer;
//
//   List<Restaurant>? _allRestaurants;
//   bool _isLoading = true;
//   String? _errorMessage;
//
//   LocationAddress? _currentAddress;
//   String? _selectedPincode;
//   bool _isLocationDetecting = false;
//   String? _locationError;
//
//   // Filter & Search states
//   String _selectedVegFilter = 'all'; // 'all', '1' (Veg), '0' (Non-Veg)
//   String _searchQuery = '';
//
//   final TextEditingController _searchController = TextEditingController();
//
//   StreamSubscription<Position>? _positionSubscription;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _initLocationAndLoadData();
//     _startStatusUpdateTimer();
//   }
//
//   /// Timer that re-evaluates Open/Closed statuses every 5 seconds
//   void _startStatusUpdateTimer() {
//     _statusUpdateTimer?.cancel();
//     _statusUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
//       if (mounted && _allRestaurants != null) {
//         setState(() {
//           // Triggers rebuild to re-evaluate isOpenNow() and move restaurants between Open & Closed
//         });
//       }
//     });
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       _initLocationAndLoadData();
//     }
//   }
//
//   String? _getVegParam() {
//     if (_selectedVegFilter == '1') return '1';
//     if (_selectedVegFilter == '0') return '0';
//     return null;
//   }
//
//   Future<void> _initLocationAndLoadData() async {
//     if (!mounted) return;
//     setState(() {
//       _isLocationDetecting = true;
//       _locationError = null;
//     });
//
//     try {
//       final pos = await LocationService.getCurrentPosition();
//       if (pos != null) {
//         final addr = await LocationService.reverseGeocode(
//           pos.latitude,
//           pos.longitude,
//         );
//         debugPrint('LOCATION DETECTED: addr=${addr?.address} pincode=${addr?.pincode}');
//         if (mounted) {
//           setState(() {
//             _currentAddress = addr;
//             if (addr != null && addr.pincode.isNotEmpty) {
//               _selectedPincode = addr.pincode;
//             } else {
//               _selectedPincode = null;
//             }
//           });
//         }
//       } else {
//         if (mounted) {
//           setState(() {
//             _locationError = 'GPS location disabled or permission denied';
//             _selectedPincode = null;
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint('Location detection error: $e');
//       if (mounted) {
//         setState(() {
//           _locationError = 'Unable to detect location automatically';
//           _selectedPincode = null;
//         });
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLocationDetecting = false;
//         });
//       }
//     }
//
//     await _fetchRestaurantList();
//   }
//
//   Future<void> _fetchRestaurantList() async {
//     if (!mounted) return;
//
//     // Case E: If pincode is null or empty, do not fetch with empty pincode or show all restaurants
//     if (_selectedPincode == null || _selectedPincode!.trim().isEmpty) {
//       setState(() {
//         _isLoading = false;
//         _allRestaurants = [];
//         _errorMessage = null;
//       });
//       return;
//     }
//
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       final list = await RestaurantRepository.getRestaurants(
//         pincode: _selectedPincode,
//         isVeg: _getVegParam(),
//       );
//       if (!mounted) return;
//
//       setState(() {
//         _allRestaurants = list;
//         _isLoading = false;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _allRestaurants = null;
//         _errorMessage =
//         'Unable to load restaurants. Please check your connection and retry.';
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _openLocationPicker() async {
//     final selected = await Navigator.push<LocationAddress>(
//       context,
//       MaterialPageRoute(
//         builder: (_) => LocationPickerScreen(
//           initialLocation: _currentAddress,
//         ),
//       ),
//     );
//
//     if (selected != null && mounted) {
//       setState(() {
//         _currentAddress = selected;
//         _selectedPincode =
//         selected.pincode.isNotEmpty ? selected.pincode : null;
//         _locationError = null;
//       });
//       await _fetchRestaurantList();
//     }
//   }
//
//   void _onFilterChanged(String filterValue) {
//     if (_selectedVegFilter == filterValue) return;
//     setState(() {
//       _selectedVegFilter = filterValue;
//     });
//     _fetchRestaurantList();
//   }
//
//   void _onRestaurantSelected(Restaurant restaurant) {
//     if (restaurant.isOpenNow()) {
//       final rawUrl = restaurant.url.trim();
//
//       if (rawUrl.isEmpty) {
//         _showErrorSnackBar('Invalid restaurant menu link.');
//         return;
//       }
//
//       final formattedUrl =
//       (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))
//           ? rawUrl
//           : 'https://$rawUrl';
//
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => WebViewScreen(
//             initialUrl: formattedUrl,
//             selectedRestaurant: restaurant,
//             restaurants: _allRestaurants,
//             pincode: _selectedPincode,
//             isVeg: _getVegParam(),
//           ),
//         ),
//       );
//     } else {
//       // Closed restaurant: Open Closed Details Screen with live countdown
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => ClosedRestaurantScreen(
//             restaurant: restaurant,
//             allRestaurants: _allRestaurants,
//           ),
//         ),
//       ).then((_) {
//         if (mounted) setState(() {});
//       });
//     }
//   }
//
//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: AppTheme.closedRed,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _statusUpdateTimer?.cancel();
//     _searchController.dispose();
//     WidgetsBinding.instance.removeObserver(this);
//     _positionSubscription?.cancel();
//     super.dispose();
//   }
//
//   // =====================================================
//   // BUILD
//   // =====================================================
//
//   @override
//   Widget build(BuildContext context) {
//     final double topPad = MediaQuery.of(context).padding.top;
//
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         top: false,
//         child: Stack(
//           children: [
//             // Everything scrolls inside ONE scroll view:
//             //   header (scrolls away) -> search bar (PINS at top) ->
//             //   filter chips (scroll away) -> restaurants.
//             Padding(
//               padding: EdgeInsets.only(top: topPad),
//               child: RefreshIndicator(
//                 onRefresh: _initLocationAndLoadData,
//                 color: AppTheme.primary,
//                 child: CustomScrollView(
//                   physics: const AlwaysScrollableScrollPhysics(),
//                   slivers: [
//                     // 1. ORANGE HEADER - scrolls away
//                     SliverToBoxAdapter(child: _buildHeader()),
//
//                     // 2. SEARCH BAR - stays pinned at the top
//                     SliverPersistentHeader(
//                       pinned: true,
//                       delegate: _SearchHeaderDelegate(
//                         height: 64,
//                         pinnedColor: AppTheme.primaryDark,
//                         child: _buildSearchBar(),
//                       ),
//                     ),
//
//                     // 3. FILTER CHIPS - scroll away
//                     SliverToBoxAdapter(child: _buildFilterChips()),
//
//                     // 4. RESTAURANTS - keep scrolling
//                     ..._buildContentSlivers(),
//                   ],
//                 ),
//               ),
//             ),
//
//             // Solid orange strip behind the status bar (time, signal,
//             // battery), always visible, so pinned search bar looks like
//             // an app bar.
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               height: topPad,
//               child: Container(color: AppTheme.primaryDark),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // =====================================================
//   // HEADER (title + location)
//   // =====================================================
//
//   Widget _buildHeader() {
//     String addressText;
//     String pincodeText;
//
//     if (_isLocationDetecting && _currentAddress == null) {
//       addressText = 'Getting your location...';
//       pincodeText = 'Please wait...';
//     } else if (_currentAddress != null) {
//       addressText = _currentAddress!.address;
//       pincodeText = _selectedPincode != null && _selectedPincode!.isNotEmpty
//           ? 'Pincode: $_selectedPincode'
//           : 'Pincode unresolved (Tap Change)';
//     } else {
//       addressText = _locationError ?? 'Location not available';
//       pincodeText = 'Tap Change to set location';
//     }
//
//     return Container(
//       padding: const EdgeInsets.only(
//         top: 6,
//         left: 16,
//         right: 16,
//         bottom: 12,
//       ),
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [AppTheme.primaryDark, AppTheme.primary],
//         ),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Row 1: App Title
//           const Row(
//             children: [
//               Icon(Icons.restaurant_menu, color: Colors.white, size: 22),
//               SizedBox(width: 8),
//               Text(
//                 'NEXDROP',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//
//           // Row 2: Location icon + Address & Pincode + "Change" pill button
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               const Icon(Icons.location_on, color: Colors.white, size: 20),
//               const SizedBox(width: 6),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Flexible(
//                           child: Text(
//                             addressText,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(
//                               fontSize: 13,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                         if (_isLocationDetecting) ...[
//                           const SizedBox(width: 6),
//                           const SizedBox(
//                             width: 10,
//                             height: 10,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 1.5,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ],
//                       ],
//                     ),
//                     Text(
//                       pincodeText,
//                       style: const TextStyle(
//                         fontSize: 11,
//                         color: Colors.white70,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 8),
//               OutlinedButton(
//                 onPressed: _openLocationPicker,
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: Colors.white,
//                   side: const BorderSide(color: Colors.white, width: 1.2),
//                   padding:
//                   const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   minimumSize: Size.zero,
//                   tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                 ),
//                 child: const Text(
//                   'Change',
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   // =====================================================
//   // SEARCH BAR & FILTER CHIPS
//   // =====================================================
//
//   Widget _buildSearchBar() {
//     return Container(
//       height: 42,
//       decoration: BoxDecoration(
//         color: const Color(0xFFF2F4F7),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: TextField(
//         controller: _searchController,
//         onChanged: (val) {
//           setState(() => _searchQuery = val);
//         },
//         decoration: InputDecoration(
//           hintText: 'Search for restaurants...',
//           hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
//           prefixIcon:
//           const Icon(Icons.search, size: 20, color: AppTheme.primaryDark),
//           suffixIcon: _searchQuery.isNotEmpty
//               ? IconButton(
//             icon: const Icon(Icons.clear, size: 18),
//             onPressed: () {
//               _searchController.clear();
//               setState(() => _searchQuery = '');
//             },
//           )
//               : null,
//           border: InputBorder.none,
//           contentPadding: const EdgeInsets.symmetric(vertical: 10),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildFilterChips() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
//       child: Row(
//         children: [
//           _buildChip(
//             label: 'All',
//             isSelected: _selectedVegFilter == 'all',
//             onTap: () => _onFilterChanged('all'),
//           ),
//           const SizedBox(width: 8),
//           _buildChip(
//             label: 'Veg',
//             isSelected: _selectedVegFilter == '1',
//             onTap: () => _onFilterChanged('1'),
//             icon: Icons.circle,
//             iconColor: AppTheme.openGreen,
//           ),
//           const SizedBox(width: 8),
//           _buildChip(
//             label: 'Non-Veg',
//             isSelected: _selectedVegFilter == '0',
//             onTap: () => _onFilterChanged('0'),
//             icon: Icons.change_history,
//             iconColor: AppTheme.closedRed,
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildChip({
//     required String label,
//     required bool isSelected,
//     required VoidCallback onTap,
//     IconData? icon,
//     Color? iconColor,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
//         decoration: BoxDecoration(
//           color: isSelected ? AppTheme.primary : AppTheme.chipUnselected,
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             if (icon != null) ...[
//               Icon(
//                 icon,
//                 size: 10,
//                 color: isSelected
//                     ? Colors.white
//                     : (iconColor ?? AppTheme.textDark),
//               ),
//               const SizedBox(width: 5),
//             ],
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.bold,
//                 color: isSelected ? Colors.white : AppTheme.textDark,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // =====================================================
//   // CONTENT (as slivers, so everything scrolls together)
//   // =====================================================
//
//   Widget _padSliver(Widget sliver) {
//     return SliverPadding(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       sliver: sliver,
//     );
//   }
//
//   List<Widget> _buildContentSlivers() {
//     if (_isLocationDetecting || _isLoading) {
//       return [
//         const SliverFillRemaining(
//           child: RestaurantSkeleton(),
//         ),
//       ];
//     }
//
//     if (_errorMessage != null) {
//       return [
//         SliverFillRemaining(
//           hasScrollBody: false,
//           child: Center(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Icon(Icons.wifi_off_rounded,
//                       size: 56, color: Colors.orange),
//                   const SizedBox(height: 16),
//                   Text(
//                     _errorMessage!,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                         fontSize: 15, color: AppTheme.textDark),
//                   ),
//                   const SizedBox(height: 20),
//                   ElevatedButton.icon(
//                     onPressed: _fetchRestaurantList,
//                     icon: const Icon(Icons.refresh),
//                     label: const Text('Retry'),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ];
//     }
//
//     // Unresolved location or missing pincode state (Case E)
//     if (_selectedPincode == null || _selectedPincode!.trim().isEmpty) {
//       return [
//         SliverFillRemaining(
//           hasScrollBody: false,
//           child: Center(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Icon(Icons.location_off_rounded,
//                       size: 56, color: Colors.orange),
//                   const SizedBox(height: 16),
//                   Text(
//                     _currentAddress != null
//                         ? 'Pincode not resolved for location'
//                         : 'Location Not Set',
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: AppTheme.textDark,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     _currentAddress != null
//                         ? 'We could not determine the delivery pincode for this location. Please select a location manually.'
//                         : (_locationError ?? 'Please enable location services or select your location manually.'),
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
//                   ),
//                   const SizedBox(height: 20),
//                   ElevatedButton.icon(
//                     onPressed: _openLocationPicker,
//                     icon: const Icon(Icons.pin_drop_rounded),
//                     label: const Text('Select Location'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: AppTheme.primary,
//                       foregroundColor: Colors.white,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ];
//     }
//
//     // Empty state when backend has no restaurants for the pincode (Case B & C)
//     if (_allRestaurants == null || _allRestaurants!.isEmpty) {
//       return [
//         SliverFillRemaining(
//           hasScrollBody: false,
//           child: Center(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Icon(Icons.storefront_outlined,
//                       size: 56, color: Colors.grey),
//                   const SizedBox(height: 16),
//                   const Text(
//                     'No restaurants available',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: AppTheme.textDark,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'There are no restaurants delivering to pincode $_selectedPincode at the moment.',
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
//                   ),
//                   const SizedBox(height: 20),
//                   OutlinedButton.icon(
//                     onPressed: _openLocationPicker,
//                     icon: const Icon(Icons.edit_location_alt),
//                     label: const Text('Change Location'),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ];
//     }
//
//     // Filter restaurants by search query
//     List<Restaurant> list = List.from(_allRestaurants!);
//     if (_searchQuery.trim().isNotEmpty) {
//       final q = _searchQuery.trim().toLowerCase();
//       list = list.where((r) => r.name.toLowerCase().contains(q)).toList();
//     }
//
//     // Separate Open and Closed restaurants
//     final openRestaurants = list.where((r) => r.isOpenNow()).toList()
//       ..sort((a, b) => a.sequence.compareTo(b.sequence));
//
//     final closedRestaurants = list.where((r) => !r.isOpenNow()).toList()
//       ..sort((a, b) => a.sequence.compareTo(b.sequence));
//
//     // Top rated open restaurants (Rating >= 4.0, sorted by rating descending)
//     final topRatedRestaurants = list
//         .where((r) => r.rating >= 4.0)
//         .toList()
//       ..sort((a, b) {
//         final aOpen = a.isOpenNow();
//         final bOpen = b.isOpenNow();
//         if (aOpen != bOpen) return aOpen ? -1 : 1;
//         return b.rating.compareTo(a.rating);
//       });
//
//     if (openRestaurants.isEmpty && closedRestaurants.isEmpty) {
//       return [
//         SliverFillRemaining(
//           hasScrollBody: false,
//           child: Center(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Icon(Icons.search_off, size: 56, color: Colors.grey),
//                   const SizedBox(height: 16),
//                   Text(
//                     'No restaurants found for "$_searchQuery"',
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                         fontSize: 15, color: AppTheme.textMuted),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ];
//     }
//
//     return [
//       // 1. TOP RATED Section
//       if (topRatedRestaurants.isNotEmpty)
//         _padSliver(
//           SliverToBoxAdapter(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const SizedBox(height: 8),
//                 const Text(
//                   'Top Rated',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: AppTheme.textDark,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 SizedBox(
//                   height: 180,
//                   child: ListView.builder(
//                     scrollDirection: Axis.horizontal,
//                     itemCount: topRatedRestaurants.length,
//                     itemBuilder: (context, index) {
//                       final restaurant = topRatedRestaurants[index];
//                       return _buildTopRatedCard(restaurant);
//                     },
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//               ],
//             ),
//           ),
//         ),
//
//       // 2. Restaurants to Explore Section
//       if (openRestaurants.isNotEmpty) ...[
//         _padSliver(
//           const SliverToBoxAdapter(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Restaurants to explore',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: AppTheme.textDark,
//                   ),
//                 ),
//                 SizedBox(height: 2),
//                 Text(
//                   'Featured Restaurants',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: AppTheme.textMuted,
//                   ),
//                 ),
//                 SizedBox(height: 12),
//               ],
//             ),
//           ),
//         ),
//         _padSliver(
//           SliverList(
//             delegate: SliverChildBuilderDelegate(
//                   (context, index) {
//                 final restaurant = openRestaurants[index];
//                 return RestaurantCard(
//                   restaurant: restaurant,
//                   userLat: _currentAddress?.latitude,
//                   userLng: _currentAddress?.longitude,
//                   onTap: () => _onRestaurantSelected(restaurant),
//                 );
//               },
//               childCount: openRestaurants.length,
//             ),
//           ),
//         ),
//       ],
//
//       // 3. Closed for Delivery Section
//       if (closedRestaurants.isNotEmpty) ...[
//         _padSliver(
//           const SliverToBoxAdapter(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SizedBox(height: 16),
//                 Text(
//                   'Closed for Delivery',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: AppTheme.textDark,
//                   ),
//                 ),
//                 SizedBox(height: 12),
//               ],
//             ),
//           ),
//         ),
//         _padSliver(
//           SliverList(
//             delegate: SliverChildBuilderDelegate(
//                   (context, index) {
//                 final restaurant = closedRestaurants[index];
//                 return RestaurantCard(
//                   restaurant: restaurant,
//                   userLat: _currentAddress?.latitude,
//                   userLng: _currentAddress?.longitude,
//                   onTap: () => _onRestaurantSelected(restaurant),
//                 );
//               },
//               childCount: closedRestaurants.length,
//             ),
//           ),
//         ),
//       ],
//
//       // Bottom breathing space
//       const SliverToBoxAdapter(child: SizedBox(height: 16)),
//     ];
//   }
//
//   /// Blank area + small API logo, used when a restaurant has no banner.
//   Widget _buildTopRatedNoBanner(String logoUrl) {
//     return Container(
//       width: double.infinity,
//       height: double.infinity,
//       color: const Color(0xFFF2F4F7),
//       child: Center(
//         child: logoUrl.isNotEmpty
//             ? Container(
//           width: 46,
//           height: 46,
//           decoration: const BoxDecoration(
//             shape: BoxShape.circle,
//             color: Colors.white,
//           ),
//           child: ClipOval(
//             child: Image.network(
//               logoUrl,
//               fit: BoxFit.cover,
//               errorBuilder: (_, __, ___) => const SizedBox.shrink(),
//             ),
//           ),
//         )
//             : const SizedBox.shrink(),
//       ),
//     );
//   }
//
//   /// Small Portrait Card for Top Rated Section
//   Widget _buildTopRatedCard(Restaurant restaurant) {
//     final bannerUrls = restaurant.getFullBannerUrls();
//     final logoUrl = restaurant.getFullLogoUrl();
//     final noBanner = _buildTopRatedNoBanner(logoUrl);
//     final isOpen = restaurant.isOpenNow();
//
//     Widget image = bannerUrls.isNotEmpty
//         ? Image.network(
//       bannerUrls.first,
//       fit: BoxFit.cover,
//       width: double.infinity,
//       height: double.infinity,
//       errorBuilder: (_, __, ___) => noBanner,
//     )
//         : noBanner;
//
//     // Closed restaurants: greyscale image
//     if (!isOpen) {
//       image = ColorFiltered(
//         colorFilter: const ColorFilter.matrix(<double>[
//           0.2126, 0.7152, 0.0722, 0, 0,
//           0.2126, 0.7152, 0.0722, 0, 0,
//           0.2126, 0.7152, 0.0722, 0, 0,
//           0, 0, 0, 1, 0,
//         ]),
//         child: image,
//       );
//     }
//
//     return Container(
//       width: 130,
//       margin: const EdgeInsets.only(right: 12),
//       decoration: BoxDecoration(
//         color: AppTheme.surface,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: AppTheme.chipUnselected),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x0A000000),
//             blurRadius: 6,
//             offset: Offset(0, 2),
//           ),
//         ],
//       ),
//       child: InkWell(
//         onTap: () => _onRestaurantSelected(restaurant),
//         borderRadius: BorderRadius.circular(14),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Image with Heart Icon
//             Stack(
//               children: [
//                 SizedBox(
//                   height: 100,
//                   width: double.infinity,
//                   child: ClipRRect(
//                     borderRadius:
//                     const BorderRadius.vertical(top: Radius.circular(14)),
//                     child: image,
//                   ),
//                 ),
//                 if (!isOpen)
//                   Positioned.fill(
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.55),
//                         borderRadius: const BorderRadius.vertical(
//                             top: Radius.circular(14)),
//                       ),
//                     ),
//                   ),
//                 if (!isOpen)
//                   Positioned(
//                     left: 8,
//                     right: 8,
//                     bottom: 6,
//                     child: Text(
//                       restaurant.openingText(),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 10,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 Positioned(
//                   top: 6,
//                   right: 6,
//                   child: Container(
//                     padding: const EdgeInsets.all(4),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.85),
//                       shape: BoxShape.circle,
//                     ),
//                     child: const Icon(
//                       Icons.favorite_border,
//                       size: 14,
//                       color: AppTheme.textDark,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//
//             // Text Info
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           restaurant.name,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.bold,
//                             color: isOpen
//                                 ? AppTheme.textDark
//                                 : AppTheme.textMuted,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 4),
//                       Container(
//                         padding: const EdgeInsets.all(1.5),
//                         decoration: BoxDecoration(
//                           border: Border.all(
//                             color: restaurant.isVegetarian
//                                 ? AppTheme.openGreen
//                                 : AppTheme.closedRed,
//                             width: 1,
//                           ),
//                           borderRadius: BorderRadius.circular(3),
//                         ),
//                         child: Icon(
//                           Icons.circle,
//                           size: 5,
//                           color: restaurant.isVegetarian
//                               ? AppTheme.openGreen
//                               : AppTheme.closedRed,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 4),
//
//                   // Rating Badge
//                   Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 5, vertical: 2),
//                         decoration: BoxDecoration(
//                           color:
//                           isOpen ? AppTheme.openGreen : AppTheme.textMuted,
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Text(
//                               restaurant.rating.toStringAsFixed(1),
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(width: 2),
//                             const Icon(Icons.star,
//                                 size: 9, color: Colors.white),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/restaurant.dart';
import '../repositories/restaurant_repository.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/restaurant_skeleton.dart';
import 'closed_restaurant_screen.dart';
import 'contact_us_screen.dart';
import 'location_picker_screen.dart';
import 'webview_screen.dart';

/// Keeps the search bar pinned at the top of the screen once the orange
/// header has scrolled away. While pinned (content scrolling underneath)
/// it gets the orange colour, so it looks like the new app bar.
class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final Color pinnedColor;

  _SearchHeaderDelegate({
    required this.child,
    required this.height,
    required this.pinnedColor,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    return Container(
      height: height,
      color: overlapsContent ? pinnedColor : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) => true;
}

class RestaurantSelectionScreen extends StatefulWidget {
  const RestaurantSelectionScreen({super.key});

  @override
  State<RestaurantSelectionScreen> createState() =>
      _RestaurantSelectionScreenState();
}

class _RestaurantSelectionScreenState extends State<RestaurantSelectionScreen>
    with WidgetsBindingObserver {
  Timer? _statusUpdateTimer;

  List<Restaurant>? _allRestaurants;
  bool _isLoading = true;
  String? _errorMessage;

  LocationAddress? _currentAddress;
  String? _selectedPincode;
  bool _isLocationDetecting = false;
  String? _locationError;

  // Filter & Search states
  String _selectedVegFilter = 'all'; // 'all', '1' (Veg), '0' (Non-Veg)
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationAndLoadData();
    _startStatusUpdateTimer();
  }

  /// Timer that re-evaluates Open/Closed statuses every 5 seconds
  void _startStatusUpdateTimer() {
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _allRestaurants != null) {
        setState(() {
          // Triggers rebuild to re-evaluate isOpenNow() and move restaurants between Open & Closed
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initLocationAndLoadData();
    }
  }

  String? _getVegParam() {
    if (_selectedVegFilter == '1') return '1';
    if (_selectedVegFilter == '0') return '0';
    return null;
  }

  Future<void> _initLocationAndLoadData() async {
    if (!mounted) return;
    setState(() {
      _isLocationDetecting = true;
      _locationError = null;
    });

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        final addr = await LocationService.reverseGeocode(
          pos.latitude,
          pos.longitude,
        );
        debugPrint('LOCATION DETECTED: addr=${addr?.address} pincode=${addr?.pincode}');
        if (mounted) {
          setState(() {
            _currentAddress = addr;
            if (addr != null && addr.pincode.isNotEmpty) {
              _selectedPincode = addr.pincode;
            } else {
              _selectedPincode = null;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _locationError = 'GPS location disabled or permission denied';
            _selectedPincode = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Location detection error: $e');
      if (mounted) {
        setState(() {
          _locationError = 'Unable to detect location automatically';
          _selectedPincode = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocationDetecting = false;
        });
      }
    }

    await _fetchRestaurantList();
  }

  Future<void> _fetchRestaurantList() async {
    if (!mounted) return;

    // Case E: If pincode is null or empty, do not fetch with empty pincode or show all restaurants
    if (_selectedPincode == null || _selectedPincode!.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _allRestaurants = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await RestaurantRepository.getRestaurants(
        pincode: _selectedPincode,
        isVeg: _getVegParam(),
      );
      if (!mounted) return;

      setState(() {
        _allRestaurants = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allRestaurants = null;
        _errorMessage =
        'Unable to load restaurants. Please check your connection and retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openLocationPicker() async {
    final selected = await Navigator.push<LocationAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: _currentAddress,
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _currentAddress = selected;
        _selectedPincode =
        selected.pincode.isNotEmpty ? selected.pincode : null;
        _locationError = null;
      });
      await _fetchRestaurantList();
    }
  }

  /// Opens the Contact Us screen (back arrow there pops to this screen).
  void _openContactUs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactUsScreen()),
    );
  }

  void _onFilterChanged(String filterValue) {
    if (_selectedVegFilter == filterValue) return;
    setState(() {
      _selectedVegFilter = filterValue;
    });
    _fetchRestaurantList();
  }

  void _onRestaurantSelected(Restaurant restaurant) {
    if (restaurant.isOpenNow()) {
      final rawUrl = restaurant.url.trim();

      if (rawUrl.isEmpty) {
        _showErrorSnackBar('Invalid restaurant menu link.');
        return;
      }

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
            restaurants: _allRestaurants,
            pincode: _selectedPincode,
            isVeg: _getVegParam(),
          ),
        ),
      );
    } else {
      // Closed restaurant: Open Closed Details Screen with live countdown
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClosedRestaurantScreen(
            restaurant: restaurant,
            allRestaurants: _allRestaurants,
          ),
        ),
      ).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.closedRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _statusUpdateTimer?.cancel();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    super.dispose();
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Everything scrolls inside ONE scroll view:
            //   header (scrolls away) -> search bar (PINS at top) ->
            //   filter chips (scroll away) -> restaurants.
            Padding(
              padding: EdgeInsets.only(top: topPad),
              child: RefreshIndicator(
                onRefresh: _initLocationAndLoadData,
                color: AppTheme.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // 1. ORANGE HEADER - scrolls away
                    SliverToBoxAdapter(child: _buildHeader()),

                    // 2. SEARCH BAR - stays pinned at the top
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SearchHeaderDelegate(
                        height: 64,
                        pinnedColor: AppTheme.primaryDark,
                        child: _buildSearchBar(),
                      ),
                    ),

                    // 3. FILTER CHIPS - scroll away
                    SliverToBoxAdapter(child: _buildFilterChips()),

                    // 4. RESTAURANTS - keep scrolling
                    ..._buildContentSlivers(),
                  ],
                ),
              ),
            ),

            // Solid orange strip behind the status bar (time, signal,
            // battery), always visible, so pinned search bar looks like
            // an app bar.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topPad,
              child: Container(color: AppTheme.primaryDark),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // HEADER (title + location)
  // =====================================================

  Widget _buildHeader() {
    String addressText;
    String pincodeText;

    if (_isLocationDetecting && _currentAddress == null) {
      addressText = 'Getting your location...';
      pincodeText = 'Please wait...';
    } else if (_currentAddress != null) {
      addressText = _currentAddress!.address;
      pincodeText = _selectedPincode != null && _selectedPincode!.isNotEmpty
          ? 'Pincode: $_selectedPincode'
          : 'Pincode unresolved (Tap Change)';
    } else {
      addressText = _locationError ?? 'Location not available';
      pincodeText = 'Tap Change to set location';
    }

    return Container(
      padding: const EdgeInsets.only(
        top: 6,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryDark, AppTheme.primary],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: App Title + Contact action
          Row(
            children: [
              const Icon(Icons.restaurant_menu, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'NEXDROP',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openContactUs,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Contact',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Location icon + Address & Pincode + "Change" pill button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            addressText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (_isLocationDetecting) ...[
                          const SizedBox(width: 6),
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      pincodeText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _openLocationPicker,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.2),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SEARCH BAR & FILTER CHIPS
  // =====================================================

  Widget _buildSearchBar() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() => _searchQuery = val);
        },
        decoration: InputDecoration(
          hintText: 'Search for restaurants...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          prefixIcon:
          const Icon(Icons.search, size: 20, color: AppTheme.primaryDark),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _buildChip(
            label: 'All',
            isSelected: _selectedVegFilter == 'all',
            onTap: () => _onFilterChanged('all'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Veg',
            isSelected: _selectedVegFilter == '1',
            onTap: () => _onFilterChanged('1'),
            icon: Icons.circle,
            iconColor: AppTheme.openGreen,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Non-Veg',
            isSelected: _selectedVegFilter == '0',
            onTap: () => _onFilterChanged('0'),
            icon: Icons.change_history,
            iconColor: AppTheme.closedRed,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.chipUnselected,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 10,
                color: isSelected
                    ? Colors.white
                    : (iconColor ?? AppTheme.textDark),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // CONTENT (as slivers, so everything scrolls together)
  // =====================================================

  Widget _padSliver(Widget sliver) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: sliver,
    );
  }

  List<Widget> _buildContentSlivers() {
    if (_isLocationDetecting || _isLoading) {
      return [
        const SliverFillRemaining(
          child: RestaurantSkeleton(),
        ),
      ];
    }

    if (_errorMessage != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 56, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _fetchRestaurantList,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    // Unresolved location or missing pincode state (Case E)
    if (_selectedPincode == null || _selectedPincode!.trim().isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off_rounded,
                      size: 56, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    _currentAddress != null
                        ? 'Pincode not resolved for location'
                        : 'Location Not Set',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentAddress != null
                        ? 'We could not determine the delivery pincode for this location. Please select a location manually.'
                        : (_locationError ?? 'Please enable location services or select your location manually.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _openLocationPicker,
                    icon: const Icon(Icons.pin_drop_rounded),
                    label: const Text('Select Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    // Empty state when backend has no restaurants for the pincode (Case B & C)
    if (_allRestaurants == null || _allRestaurants!.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 56, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No restaurants available',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'There are no restaurants delivering to pincode $_selectedPincode at the moment.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _openLocationPicker,
                    icon: const Icon(Icons.edit_location_alt),
                    label: const Text('Change Location'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    // Filter restaurants by search query
    List<Restaurant> list = List.from(_allRestaurants!);
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((r) => r.name.toLowerCase().contains(q)).toList();
    }

    // Separate Open and Closed restaurants
    final openRestaurants = list.where((r) => r.isOpenNow()).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    final closedRestaurants = list.where((r) => !r.isOpenNow()).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    // Top rated open restaurants (Rating >= 4.0, sorted by rating descending)
    final topRatedRestaurants = list
        .where((r) => r.rating >= 4.0)
        .toList()
      ..sort((a, b) {
        final aOpen = a.isOpenNow();
        final bOpen = b.isOpenNow();
        if (aOpen != bOpen) return aOpen ? -1 : 1;
        return b.rating.compareTo(a.rating);
      });

    if (openRestaurants.isEmpty && closedRestaurants.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 56, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No restaurants found for "$_searchQuery"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      // 1. TOP RATED Section
      if (topRatedRestaurants.isNotEmpty)
        _padSliver(
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Top Rated',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: topRatedRestaurants.length,
                    itemBuilder: (context, index) {
                      final restaurant = topRatedRestaurants[index];
                      return _buildTopRatedCard(restaurant);
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

      // 2. Restaurants to Explore Section
      if (openRestaurants.isNotEmpty) ...[
        _padSliver(
          const SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Restaurants to explore',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Featured Restaurants',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        ),
        _padSliver(
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final restaurant = openRestaurants[index];
                return RestaurantCard(
                  restaurant: restaurant,
                  userLat: _currentAddress?.latitude,
                  userLng: _currentAddress?.longitude,
                  onTap: () => _onRestaurantSelected(restaurant),
                );
              },
              childCount: openRestaurants.length,
            ),
          ),
        ),
      ],

      // 3. Closed for Delivery Section
      if (closedRestaurants.isNotEmpty) ...[
        _padSliver(
          const SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
                Text(
                  'Closed for Delivery',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        ),
        _padSliver(
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final restaurant = closedRestaurants[index];
                return RestaurantCard(
                  restaurant: restaurant,
                  userLat: _currentAddress?.latitude,
                  userLng: _currentAddress?.longitude,
                  onTap: () => _onRestaurantSelected(restaurant),
                );
              },
              childCount: closedRestaurants.length,
            ),
          ),
        ),
      ],

      // Bottom breathing space
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ];
  }

  /// Blank area + small API logo, used when a restaurant has no banner.
  Widget _buildTopRatedNoBanner(String logoUrl) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF2F4F7),
      child: Center(
        child: logoUrl.isNotEmpty
            ? Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        )
            : const SizedBox.shrink(),
      ),
    );
  }

  /// Small Portrait Card for Top Rated Section
  Widget _buildTopRatedCard(Restaurant restaurant) {
    final bannerUrls = restaurant.getFullBannerUrls();
    final logoUrl = restaurant.getFullLogoUrl();
    final noBanner = _buildTopRatedNoBanner(logoUrl);
    final isOpen = restaurant.isOpenNow();

    Widget image = bannerUrls.isNotEmpty
        ? Image.network(
      bannerUrls.first,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => noBanner,
    )
        : noBanner;

    // Closed restaurants: greyscale image
    if (!isOpen) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: image,
      );
    }

    return Container(
      width: 130,
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
        onTap: () => _onRestaurantSelected(restaurant),
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
                    child: image,
                  ),
                ),
                if (!isOpen)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14)),
                      ),
                    ),
                  ),
                if (!isOpen)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 6,
                    child: Text(
                      restaurant.openingText(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isOpen
                                ? AppTheme.textDark
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: restaurant.isVegetarian
                                ? AppTheme.openGreen
                                : AppTheme.closedRed,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Icon(
                          Icons.circle,
                          size: 5,
                          color: restaurant.isVegetarian
                              ? AppTheme.openGreen
                              : AppTheme.closedRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Rating Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                          isOpen ? AppTheme.openGreen : AppTheme.textMuted,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}