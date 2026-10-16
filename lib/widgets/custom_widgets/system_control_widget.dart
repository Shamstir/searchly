import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:torch_light/torch_light.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';

class SystemControlWidget extends StatefulWidget {
  const SystemControlWidget({super.key});

  @override
  State<SystemControlWidget> createState() => _SystemControlWidgetState();
}

class _SystemControlWidgetState extends State<SystemControlWidget> {
  double _volume = 0.5;
  bool _isTorchOn = false;
  bool _isDefaultLauncher = false;

  @override
  void initState() {
    super.initState();
    _initVolume();
    _checkDefaultLauncher();
  }

  Future<void> _initVolume() async {
    try {
      _volume = await FlutterVolumeController.getVolume() ?? 0.5;
      if (mounted) setState(() {});

      FlutterVolumeController.addListener((volume) {
        if (mounted) setState(() => _volume = volume);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    FlutterVolumeController.removeListener();
    super.dispose();
  }

  Future<void> _checkDefaultLauncher() async {
    try {
      const platform = MethodChannel('searchly/launcher');
      final isDef = await platform.invokeMethod<bool>('isDefaultLauncher');
      if (mounted) setState(() => _isDefaultLauncher = isDef ?? false);
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    try {
      if (_isTorchOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (e) {
      debugPrint("Torch error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CONTROLS',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDDDDD)),
                ),
                child: const Text(
                  'SYSTEM',
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          // Volume Slider
          Row(
            children: [
              const Icon(Icons.volume_mute, color: Color(0xFFBBBBBB), size: 18),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: const Color(0xFF222222),
                    inactiveTrackColor: const Color(0xFFEEEEEE),
                    thumbColor: const Color(0xFF222222),
                    overlayColor: Colors.black.withValues(alpha: 0.08),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _volume.clamp(0.0, 1.0),
                    onChanged: (val) {
                      setState(() => _volume = val);
                      FlutterVolumeController.setVolume(val);
                    },
                  ),
                ),
              ),
              const Icon(Icons.volume_up, color: Color(0xFFBBBBBB), size: 18),
            ],
          ),
          // System Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildControlButton(
                icon: _isTorchOn ? Icons.flashlight_on : Icons.flashlight_off,
                label: 'Torch',
                isActive: _isTorchOn,
                onTap: _toggleTorch,
              ),
              _buildControlButton(
                icon: Icons.wifi,
                label: 'Wi-Fi',
                isActive: false,
                onTap: () {
                  AppSettings.openAppSettings(type: AppSettingsType.wifi);
                },
              ),
              _buildControlButton(
                icon: Icons.bluetooth,
                label: 'BT',
                isActive: false,
                onTap: () {
                  AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                },
              ),
              _buildControlButton(
                icon: Icons.home_outlined,
                label: 'Launcher',
                isActive: _isDefaultLauncher,
                onTap: () async {
                  const platform = MethodChannel('searchly/launcher');
                  await platform.invokeMethod('requestDefaultLauncher');
                  await Future.delayed(const Duration(seconds: 1));
                  _checkDefaultLauncher();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 64,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF222222) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFF222222) : const Color(0xFFEBEBEB),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF666666),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF666666),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
