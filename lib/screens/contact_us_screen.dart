// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../theme/app_theme.dart';
//
// class ContactUsScreen extends StatelessWidget {
//   const ContactUsScreen({super.key});
//
//   // Central contact configuration constants
//   static const String phoneNumber = '6360037793';
//   static const String whatsappNumber = '916360037793';
//   static const String emailAddress = 'myteknoland@gmail.com';
//
//   // Hero image asset (change the extension if your file is .jpg / .webp)
//   static const String heroImageAsset = 'assets/images/callgirl.png';
//
//   static const Color _pageBg = Color(0xFFFAFAFA);
//   static const Color _cardBorder = Color(0xFFE8E8E8);
//   static const Color _whatsappGreen = Color(0xFF25D366);
//   static const Color _whatsappSoft = Color(0xFFE3F6EA);
//   static const Color _emailBlue = Color(0xFF1B66C9);
//   static const Color _emailSoft = Color(0xFFE8F0FD);
//
//   // =====================================================
//   // ACTIONS
//   // =====================================================
//
//   /// Copies text to the clipboard silently (no message shown).
//   Future<void> _copySilently(String value) async {
//     try {
//       await Clipboard.setData(ClipboardData(text: value));
//     } catch (e) {
//       debugPrint('Clipboard error: $e');
//     }
//   }
//
//   void _showMessage(BuildContext context, String message, Color color) {
//     if (!context.mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: color,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
//
//   Future<void> _handleCall(BuildContext context) async {
//     // Copy in the background, then open the dialer (does not place the call).
//     await _copySilently(phoneNumber);
//
//     final telUri = Uri.parse('tel:$phoneNumber');
//     try {
//       final launched =
//       await launchUrl(telUri, mode: LaunchMode.externalApplication);
//       if (!launched && context.mounted) {
//         _showMessage(
//             context, 'Could not open the phone dialer.', AppTheme.closedRed);
//       }
//     } catch (e) {
//       debugPrint('Error launching dialer: $e');
//       if (context.mounted) {
//         _showMessage(
//             context, 'Could not open the phone dialer.', AppTheme.closedRed);
//       }
//     }
//   }
//
//   Future<void> _handleWhatsApp(BuildContext context) async {
//     final waAppUri = Uri.parse('whatsapp://send?phone=$whatsappNumber');
//     final waWebUri = Uri.parse('https://wa.me/$whatsappNumber');
//
//     // 1. WhatsApp app directly
//     try {
//       final launched =
//       await launchUrl(waAppUri, mode: LaunchMode.externalApplication);
//       if (launched) return;
//     } catch (e) {
//       debugPrint('WhatsApp app launch failed: $e');
//     }
//
//     // 2. Fallback: wa.me link (opens WhatsApp or WhatsApp Web in browser)
//     try {
//       final launched =
//       await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
//       if (launched) return;
//     } catch (e) {
//       debugPrint('WhatsApp web launch failed: $e');
//     }
//
//     if (!context.mounted) return;
//     _showMessage(
//       context,
//       'WhatsApp is not installed or could not be opened on your device.',
//       AppTheme.closedRed,
//     );
//   }
//
//   Future<void> _handleEmail(BuildContext context) async {
//     // Copy in the background, then open the mail app with recipient filled.
//     await _copySilently(emailAddress);
//
//     final mailUri = Uri(scheme: 'mailto', path: emailAddress);
//
//     // 1. Open mail app directly
//     try {
//       final launched =
//       await launchUrl(mailUri, mode: LaunchMode.externalApplication);
//       if (launched) return;
//     } catch (e) {
//       debugPrint('Email launch (external) failed: $e');
//     }
//
//     // 2. Retry with the platform default mode
//     try {
//       final launched = await launchUrl(mailUri);
//       if (launched) return;
//     } catch (e) {
//       debugPrint('Email launch (default) failed: $e');
//     }
//
//     if (!context.mounted) return;
//     _showMessage(
//       context,
//       'No email app found. Please install or set up an email app.',
//       AppTheme.primary,
//     );
//   }
//
//   // =====================================================
//   // BUILD
//   // =====================================================
//
//   @override
//   Widget build(BuildContext context) {
//     final double width = MediaQuery.of(context).size.width;
//     final double heroSize = math.min(width * 0.30, 140.0);
//
//     return Scaffold(
//       backgroundColor: _pageBg,
//       appBar: AppBar(
//         centerTitle: true,
//         title: const Text(
//           'Contact Us',
//           style: TextStyle(
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//             fontSize: 20,
//           ),
//         ),
//         backgroundColor: AppTheme.primary,
//         elevation: 0,
//         scrolledUnderElevation: 0,
//         systemOverlayStyle: SystemUiOverlayStyle.light,
//         iconTheme: const IconThemeData(color: Colors.white),
//         leading: IconButton(
//           tooltip: 'Back',
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
//           child: Center(
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 560),
//               child: Column(
//                 children: [
//                   _buildHero(heroSize),
//                   const SizedBox(height: 20),
//                   const Text(
//                     'How can we help?',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 28,
//                       fontWeight: FontWeight.w700,
//                       color: AppTheme.textDark,
//                     ),
//                   ),
//                   const SizedBox(height: 32),
//
//                   // 1. Call Us
//                   _buildContactCard(
//                     leading: const Icon(
//                       Icons.call,
//                       color: AppTheme.primary,
//                       size: 28,
//                     ),
//                     accentColor: AppTheme.primary,
//                     iconBgColor: AppTheme.primarySoft,
//                     title: 'Call Us',
//                     detail: phoneNumber,
//                     semanticHint: 'Tap to copy and open phone dialer',
//                     onTap: () => _handleCall(context),
//                   ),
//                   const SizedBox(height: 16),
//
//                   // 2. WhatsApp
//                   _buildContactCard(
//                     leading: const Icon(
//                       Icons.chat_rounded,
//                       color: _whatsappGreen,
//                       size: 30,
//                     ),
//                     accentColor: _whatsappGreen,
//                     iconBgColor: _whatsappSoft,
//                     title: 'WhatsApp',
//                     detail: '+91 $phoneNumber',
//                     semanticHint: 'Chat directly with support on WhatsApp',
//                     onTap: () => _handleWhatsApp(context),
//                   ),
//                   const SizedBox(height: 16),
//
//                   // 3. Email Us
//                   _buildContactCard(
//                     leading: const Icon(
//                       Icons.email_rounded,
//                       color: _emailBlue,
//                       size: 30,
//                     ),
//                     accentColor: _emailBlue,
//                     iconBgColor: _emailSoft,
//                     title: 'Email Us',
//                     detail: emailAddress,
//                     semanticHint: 'Send us an email',
//                     onTap: () => _handleEmail(context),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // =====================================================
//   // PIECES
//   // =====================================================
//
//   Widget _buildHero(double size) {
//     return Container(
//       width: size,
//       height: size,
//       decoration: const BoxDecoration(
//         color: AppTheme.primarySoft,
//         shape: BoxShape.circle,
//       ),
//       child: ClipOval(
//         child: Image.asset(
//           heroImageAsset,
//           width: size,
//           height: size,
//           fit: BoxFit.cover,
//           errorBuilder: (context, error, stackTrace) => Icon(
//             Icons.headset_mic_rounded,
//             size: size * 0.5,
//             color: AppTheme.primary,
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildContactCard({
//     required Widget leading,
//     required Color accentColor,
//     required Color iconBgColor,
//     required String title,
//     required String detail,
//     required String semanticHint,
//     required VoidCallback onTap,
//   }) {
//     final BorderRadius radius = BorderRadius.circular(14);
//
//     return Semantics(
//       button: true,
//       label: '$title, $detail. $semanticHint',
//       child: Material(
//         color: Colors.white,
//         shape: RoundedRectangleBorder(
//           borderRadius: radius,
//           side: const BorderSide(color: _cardBorder, width: 1),
//         ),
//         clipBehavior: Clip.antiAlias,
//         child: InkWell(
//           onTap: onTap,
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
//             child: Row(
//               children: [
//                 Container(
//                   width: 66,
//                   height: 66,
//                   decoration: BoxDecoration(
//                     color: iconBgColor,
//                     shape: BoxShape.circle,
//                   ),
//                   child: Center(child: leading),
//                 ),
//                 const SizedBox(width: 18),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         title,
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.w600,
//                           color: AppTheme.textDark,
//                         ),
//                       ),
//                       const SizedBox(height: 6),
//                       FittedBox(
//                         fit: BoxFit.scaleDown,
//                         alignment: Alignment.centerLeft,
//                         child: Text(
//                           detail,
//                           maxLines: 1,
//                           style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.w500,
//                             color: accentColor,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(width: 6),
//                 Icon(
//                   Icons.chevron_right_rounded,
//                   color: Colors.grey.shade500,
//                   size: 30,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  // Central contact configuration constants
  static const String phoneNumber = '9182378253';
  static const String whatsappNumber = '919182378253';
  static const String emailAddress = 'support@myteknoland.com';

  // Hero image asset (change the extension if your file is .jpg / .webp)
  static const String heroImageAsset = 'assets/images/callgirl.png';

  static const Color _pageBg = Color(0xFFFAFAFA);
  static const Color _cardBorder = Color(0xFFE8E8E8);
  static const Color _whatsappSoft = Color(0xFFE3F6EA);
  static const Color _emailBlue = Color(0xFF1B66C9);
  static const Color _emailSoft = Color(0xFFE8F0FD);
  static const Color _whatsappGreen = Color(0xFF25D366);

  // =====================================================
  // ACTIONS
  // =====================================================

  void _showMessage(BuildContext context, String message, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Opens the phone dialer (does not place the call).
  Future<void> _handleCall(BuildContext context) async {
    final telUri = Uri.parse('tel:$phoneNumber');
    try {
      final launched =
      await launchUrl(telUri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _showMessage(
            context, 'Could not open the phone dialer.', AppTheme.closedRed);
      }
    } catch (e) {
      debugPrint('Error launching dialer: $e');
      if (context.mounted) {
        _showMessage(
            context, 'Could not open the phone dialer.', AppTheme.closedRed);
      }
    }
  }

  Future<void> _handleWhatsApp(BuildContext context) async {
    final waAppUri = Uri.parse('whatsapp://send?phone=$whatsappNumber');
    final waWebUri = Uri.parse('https://wa.me/$whatsappNumber');

    // 1. WhatsApp app directly
    try {
      final launched =
      await launchUrl(waAppUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (e) {
      debugPrint('WhatsApp app launch failed: $e');
    }

    // 2. Fallback: wa.me link (opens WhatsApp or WhatsApp Web in browser)
    try {
      final launched =
      await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (e) {
      debugPrint('WhatsApp web launch failed: $e');
    }

    if (!context.mounted) return;
    _showMessage(
      context,
      'WhatsApp is not installed or could not be opened on your device.',
      AppTheme.closedRed,
    );
  }

  /// Opens the mail app with the recipient filled in.
  Future<void> _handleEmail(BuildContext context) async {
    final mailUri = Uri(scheme: 'mailto', path: emailAddress);

    // 1. Open mail app directly
    try {
      final launched =
      await launchUrl(mailUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (e) {
      debugPrint('Email launch (external) failed: $e');
    }

    // 2. Retry with the platform default mode
    try {
      final launched = await launchUrl(mailUri);
      if (launched) return;
    } catch (e) {
      debugPrint('Email launch (default) failed: $e');
    }

    if (!context.mounted) return;
    _showMessage(
      context,
      'No email app found. Please install or set up an email app.',
      AppTheme.primary,
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double heroSize = math.min(width * 0.30, 140.0);

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Contact Us',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  _buildHero(heroSize),
                  const SizedBox(height: 20),
                  const Text(
                    'How can we help?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 1. Call Us
                  _buildContactCard(
                    leading: const Icon(
                      Icons.call,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                    accentColor: AppTheme.primary,
                    iconBgColor: AppTheme.primarySoft,
                    title: 'Call Us',
                    detail: phoneNumber,
                    semanticHint: 'Tap to open phone dialer',
                    onTap: () => _handleCall(context),
                  ),
                  const SizedBox(height: 16),

                  // 2. WhatsApp
                  _buildContactCard(
                    leading: const _WhatsAppLogo(size: 40),
                    accentColor: _whatsappGreen,
                    iconBgColor: _whatsappSoft,
                    title: 'WhatsApp',
                    detail: '+91 $phoneNumber',
                    semanticHint: 'Chat directly with support on WhatsApp',
                    onTap: () => _handleWhatsApp(context),
                  ),
                  const SizedBox(height: 16),

                  // 3. Email Us
                  _buildContactCard(
                    leading: const Icon(
                      Icons.mail_rounded,
                      color: _emailBlue,
                      size: 28,
                    ),
                    accentColor: _emailBlue,
                    iconBgColor: _emailSoft,
                    title: 'Email Us',
                    detail: emailAddress,
                    semanticHint: 'Send us an email',
                    onTap: () => _handleEmail(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // PIECES
  // =====================================================

  Widget _buildHero(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.primarySoft,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          heroImageAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.headset_mic_rounded,
            size: size * 0.5,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required Widget leading,
    required Color accentColor,
    required Color iconBgColor,
    required String title,
    required String detail,
    required String semanticHint,
    required VoidCallback onTap,
  }) {
    final BorderRadius radius = BorderRadius.circular(14);

    return Semantics(
      button: true,
      label: '$title, $detail. $semanticHint',
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: _cardBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: leading),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          detail,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade500,
                  size: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// WHATSAPP LOGO (drawn in code, no package or image needed)
// =====================================================

class _WhatsAppLogo extends StatelessWidget {
  const _WhatsAppLogo({this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WhatsAppPainter(),
        child: Center(
          child: Icon(
            Icons.call,
            color: Colors.white,
            size: size * 0.48,
          ),
        ),
      ),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint green = Paint()..color = const Color(0xFF25D366);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width * 0.46;

    // Main bubble
    canvas.drawCircle(center, radius, green);

    // Bubble tail (bottom-left)
    final Path tail = Path()
      ..moveTo(size.width * 0.06, size.height * 0.95)
      ..lineTo(size.width * 0.10, size.height * 0.62)
      ..lineTo(size.width * 0.36, size.height * 0.88)
      ..close();
    canvas.drawPath(tail, green);

    // White ring inside the bubble
    final Paint ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    canvas.drawCircle(center, radius * 0.78, ring);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}