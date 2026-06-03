import 'dart:async';
import 'dart:convert';
import 'dart:io';

class NexDinePrinter {
  NexDinePrinter({required this.ip, this.port = 9100, this.name = 'ESC/POS Printer'});
  final String ip;
  final int port;
  final String name;
}

class NexDinePrintSdk {
  Future<List<NexDinePrinter>> discoverPrinters({
    required String subnetPrefix, // example: 192.168.1
    Duration timeout = const Duration(milliseconds: 250),
  }) async {
    final printers = <NexDinePrinter>[];

    await Future.wait(List.generate(254, (i) async {
      final ip = '$subnetPrefix.${i + 1}';
      try {
        final socket = await Socket.connect(ip, 9100, timeout: timeout);
        socket.destroy();
        printers.add(NexDinePrinter(ip: ip, name: 'Network Printer $ip'));
      } catch (_) {}
    }));

    return printers;
  }

  Future<void> testPrint(NexDinePrinter printer) {
    return printRaw(printer, [
      0x1B, 0x40,
      ...utf8.encode('NEXDINE TEST PRINT\n'),
      ...utf8.encode('${DateTime.now()}\n\n'),
      0x1D, 0x56, 0x00,
    ]);
  }

  Future<void> printReceipt(NexDinePrinter printer, String text) {
    return printRaw(printer, [
      0x1B, 0x40,
      ...utf8.encode(text),
      ...utf8.encode('\n\n\n'),
      0x1D, 0x56, 0x00,
    ]);
  }

  Future<void> printRaw(NexDinePrinter printer, List<int> bytes) async {
    final socket = await Socket.connect(
      printer.ip,
      printer.port,
      timeout: const Duration(seconds: 2),
    );

    socket.add(bytes);
    await socket.flush();
    await socket.close();
  }
}