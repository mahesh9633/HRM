import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';

class UsbPrinterManager {
  PrinterDevice? _selectedPrinter;
  bool _isConnected = false;

  Future<List<PrinterDevice>> getDevices() async {
    final devices = <PrinterDevice>[];
    PrinterManager.instance
        .discovery(type: PrinterType.usb)
        .listen((device) {
      devices.add(device);
    });
    await Future.delayed(const Duration(seconds: 2));
    return devices;
  }

  Future<bool> connectToFirst() async {
    try {
      final devices = await getDevices();
      if (devices.isEmpty) {
        debugPrint('No USB printer found');
        return false;
      }
      _selectedPrinter = devices.first;
      await PrinterManager.instance.connect(
        type: PrinterType.usb,
        model: UsbPrinterInput(
          name: _selectedPrinter!.name,
          productId: _selectedPrinter!.productId,
          vendorId: _selectedPrinter!.vendorId,
        ),
      );
      _isConnected = true;
      debugPrint('USB connected: ${_selectedPrinter!.name}');
      return true;
    } catch (e) {
      debugPrint('USB connect error: $e');
      return false;
    }
  }

  Future<void> printKioskContent(String content) async {
    if (!_isConnected) {
      final ok = await connectToFirst();
      if (!ok) return;
    }

    try {
      final profile   = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.text(
        'Krishna Mayuri',
        styles: const PosStyles(
          bold: true,
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.hr();

      final plainText = content
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&nbsp;', ' ')
          .trim();

      for (final line in plainText.split('\n')) {
        if (line.trim().isNotEmpty) {
          bytes += generator.text(line.trim());
        }
      }

      bytes += generator.feed(2);
      bytes += generator.cut();

      await PrinterManager.instance.send(
        type: PrinterType.usb,
        bytes: bytes,
      );
      debugPrint('USB print done');
    } catch (e) {
      debugPrint('USB print error: $e');
    }
  }

  void disconnect() {
    PrinterManager.instance.disconnect(type: PrinterType.usb);
    _isConnected = false;
  }
}