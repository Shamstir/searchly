import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter_media_controller/flutter_media_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:searchly/services/weather_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _weatherService = WeatherService();
  final _cityController = TextEditingController();

  bool _isDefaultLauncher = false;
  bool _contactsGranted = false;
  bool _usageStatsGranted = false;
  bool _photosGranted = false;
  bool _dynamicBgEnabled = true;
  bool _clock24h = true;
  String _searchEngine = 'Google';

  final List<String> _searchEngines = [
    'Google',
    'DuckDuckGo',
    'Bing',
    'Brave',
    'YouTube',
    'Wikipedia',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkPermissions();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dynamicBgEnabled = prefs.getBool('setting_dynamic_bg') ?? true;
      _clock24h = prefs.getBool('setting_clock_24h') ?? true;
      _searchEngine = prefs.getString('setting_search_engine') ?? 'Google';
    });
    final customCity = await _weatherService.getCustomCity();
    if (customCity != null) {
      _cityController.text = customCity;
    }
  }

  Future<void> _checkPermissions() async {
    // 1. Default launcher
    try {
      const platform = MethodChannel('searchly/launcher');
      final isDef = await platform.invokeMethod<bool>('isDefaultLauncher');
      _isDefaultLauncher = isDef ?? false;
    } catch (_) {}

    // 2. Contacts
    _contactsGranted = await Permission.contacts.isGranted;

    // 3. Usage stats
    try {
      _usageStatsGranted = await UsageStats.checkUsagePermission() ?? false;
    } catch (_) {}

    // 4. Photos
    _photosGranted = await Permission.photos.isGranted ||
        await Permission.storage.isGranted;

    if (mounted) setState(() {});
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void _showCityDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Custom Weather City', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _cityController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. London, New York, Tokyo',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _cityController.clear();
                _weatherService.setCustomCity('');
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Auto-Detect', style: TextStyle(color: Colors.cyanAccent)),
            ),
            TextButton(
              onPressed: () {
                _weatherService.setCustomCity(_cityController.text);
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Section: Permissions
          _buildSectionHeader('SYSTEM & PERMISSIONS'),
          _buildCard([
            _buildPermissionTile(
              icon: Icons.home_outlined,
              title: 'Default Launcher',
              subtitle: _isDefaultLauncher ? 'Searchly is active' : 'Set as home screen',
              isGranted: _isDefaultLauncher,
              onTap: () async {
                const platform = MethodChannel('searchly/launcher');
                await platform.invokeMethod('requestDefaultLauncher');
                await Future.delayed(const Duration(seconds: 1));
                _checkPermissions();
              },
            ),
            _buildDivider(),
            _buildPermissionTile(
              icon: Icons.contacts_outlined,
              title: 'Contacts Access',
              subtitle: 'Quick call & WhatsApp commands',
              isGranted: _contactsGranted,
              onTap: () async {
                await Permission.contacts.request();
                _checkPermissions();
              },
            ),
            _buildDivider(),
            _buildPermissionTile(
              icon: Icons.bar_chart_outlined,
              title: 'Usage Access',
              subtitle: 'Powers Screen Time widget',
              isGranted: _usageStatsGranted,
              onTap: () async {
                await UsageStats.grantUsagePermission();
                _checkPermissions();
              },
            ),
            _buildDivider(),
            _buildPermissionTile(
              icon: Icons.photo_library_outlined,
              title: 'Photos & Storage',
              subtitle: 'Powers Image Gallery widget',
              isGranted: _photosGranted,
              onTap: () async {
                await Permission.photos.request();
                _checkPermissions();
              },
            ),
            _buildDivider(),
            _buildPermissionTile(
              icon: Icons.music_note_outlined,
              title: 'Notification & Media Listener',
              subtitle: 'Dynamic album art & playback controls',
              isGranted: true,
              onTap: () async {
                await FlutterMediaController.requestPermissions();
              },
            ),
          ]),

          const SizedBox(height: 24),

          // Section: Weather
          _buildSectionHeader('WEATHER & LOCATION'),
          AnimatedBuilder(
            animation: _weatherService,
            builder: (context, _) {
              return _buildCard([
                ListTile(
                  title: const Text('Temperature Unit', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    _weatherService.isFahrenheit ? 'Fahrenheit (°F)' : 'Celsius (°C)',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  trailing: Switch(
                    value: _weatherService.isFahrenheit,
                    activeThumbColor: Colors.deepPurpleAccent,
                    onChanged: (val) {
                      _weatherService.setUnitFahrenheit(val);
                    },
                  ),
                ),
                _buildDivider(),
                ListTile(
                  title: const Text('Location', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    _weatherService.currentWeather?.cityName ?? 'Auto-detecting...',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_location_alt, color: Colors.white70),
                    onPressed: _showCityDialog,
                  ),
                ),
                _buildDivider(),
                ListTile(
                  title: const Text('Refresh Weather Data', style: TextStyle(color: Colors.white)),
                  trailing: _weatherService.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh, color: Colors.white70),
                  onTap: () => _weatherService.fetchWeather(force: true),
                ),
              ]);
            },
          ),

          const SizedBox(height: 24),

          // Section: Search & Omnibar
          _buildSectionHeader('SEARCH & OMNIBAR'),
          _buildCard([
            ListTile(
              title: const Text('Default Search Engine', style: TextStyle(color: Colors.white)),
              subtitle: Text(_searchEngine, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              trailing: DropdownButton<String>(
                value: _searchEngine,
                dropdownColor: const Color(0xFF1E1E1E),
                underline: const SizedBox(),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: _searchEngines.map((e) {
                  return DropdownMenuItem(value: e, child: Text(e));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _searchEngine = val);
                    _savePreference('setting_search_engine', val);
                  }
                },
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Section: Appearance
          _buildSectionHeader('APPEARANCE & CLOCK'),
          _buildCard([
            ListTile(
              title: const Text('Dynamic Media Background', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Blurs active album artwork across dashboard', style: TextStyle(color: Colors.white54, fontSize: 13)),
              trailing: Switch(
                value: _dynamicBgEnabled,
                activeThumbColor: Colors.deepPurpleAccent,
                onChanged: (val) {
                  setState(() => _dynamicBgEnabled = val);
                  _savePreference('setting_dynamic_bg', val);
                },
              ),
            ),
            _buildDivider(),
            ListTile(
              title: const Text('24-Hour Clock Format', style: TextStyle(color: Colors.white)),
              subtitle: Text(_clock24h ? '14:30' : '2:30 PM', style: const TextStyle(color: Colors.white54, fontSize: 13)),
              trailing: Switch(
                value: _clock24h,
                activeThumbColor: Colors.deepPurpleAccent,
                onChanged: (val) {
                  setState(() => _clock24h = val);
                  _savePreference('setting_clock_24h', val);
                },
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Section: About
          _buildSectionHeader('ABOUT SEARCHLY'),
          _buildCard([
            const ListTile(
              title: Text('Version', style: TextStyle(color: Colors.white)),
              trailing: Text('1.0.0 (Production Build)', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
            _buildDivider(),
            ListTile(
              title: const Text('Reset Dashboard Layout', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Restore default widget order and sizes', style: TextStyle(color: Colors.white54, fontSize: 13)),
              trailing: const Icon(Icons.restore, color: Colors.orangeAccent),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('widget_order_v1');
                await prefs.remove('widget_sizes_v1');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dashboard layout reset to defaults')),
                  );
                }
              },
            ),
            _buildDivider(),
            ListTile(
              title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
              onTap: () async {
                final url = Uri.parse('https://searchly.io/privacy');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.06),
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isGranted
              ? Colors.greenAccent.withValues(alpha: 0.15)
              : Colors.orangeAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGranted ? Colors.greenAccent : Colors.orangeAccent,
            width: 1,
          ),
        ),
        child: Text(
          isGranted ? 'ACTIVE' : 'GRANT',
          style: TextStyle(
            color: isGranted ? Colors.greenAccent : Colors.orangeAccent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
