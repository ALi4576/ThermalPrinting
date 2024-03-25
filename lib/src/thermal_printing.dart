import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

/// ThermalPrint class
class ThermalPrint {
  /// Check if the device is a bluetooth device
  bool get isBluetoothDevice => Platform.isAndroid || Platform.isIOS;

  /// Check if the device is a network device
  Future<bool> get bluetoothEnabled async =>
      isBluetoothDevice && await PrintBluetoothThermal.bluetoothEnabled;

  /// Check if the device is connected to a bluetooth device
  Future<bool> get bluetoothConnected async =>
      isBluetoothDevice &&
      await PrintBluetoothThermal.bluetoothEnabled &&
      await PrintBluetoothThermal.connectionStatus;

  /// Get the list of print devices
  Future<List<Map>> getPrintDevices() async {
    if (await bluetoothEnabled) {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      if (devices.isEmpty) return List.empty();
      return devices
          .map((device) => {
                'name': device.name,
                'mac': device.macAdress,
              })
          .toList();
    } else {
      final devices = await CapabilityProfile.getAvailableProfiles();
      if (devices.isEmpty) return List.empty();
      return devices
          .map((device) => {
                'name': device.name,
                'mac': device.macAdress,
              })
          .toList();
    }
  }

  /// Connect to a paired device
  Future<bool> connectPairedDevice({required String mac}) async {
    if (mac.isNotEmpty) {
      await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    }
    return await PrintBluetoothThermal.connectionStatus;
  }

  /// Disconnect from a paired device
  Future<bool> disconnectPairedDevice() async {
    await PrintBluetoothThermal.disconnect;
    return await PrintBluetoothThermal.connectionStatus;
  }

  /// Print receipt
  Future<void> printReceipt({
    required Uint8List bytes,
    required String ip,
  }) async {
    if (await bluetoothConnected) {
      await PrintBluetoothThermal.writeBytes(bytes);
    } else {
      const PaperSize paper = PaperSize.mm80;
      final profile = await CapabilityProfile.load();
      final generator = Generator(paper, profile);
      final printer = NetworkPrinter(paper, profile);

      final PosPrintResult res = await printer.connect(ip, port: 9100);

      if (res == PosPrintResult.success) {
        generator.textEncoded(bytes);
        generator.feed(2);
        generator.cut();
      }
    }
  }
}
