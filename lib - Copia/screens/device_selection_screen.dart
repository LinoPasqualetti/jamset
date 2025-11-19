// lib/screens/device_selection_screen.dart

import 'package:flutter/material.dart';

class DeviceSelectionScreen extends StatelessWidget {
  const DeviceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu di Selezione'),
      ),
      body: const Center(
        child: Text('Qui potresti scegliere il device o la modalità'),
      ),
    );
  }
}