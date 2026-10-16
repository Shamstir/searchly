import 'package:flutter/material.dart';
import 'package:searchly/services/weather_service.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  final _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    _weatherService.init();
  }

  void _showForecastSheet(BuildContext context, WeatherData weather) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18191C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      weather.cityName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () {
                        _weatherService.fetchWeather(force: true);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_weatherService.formatTemp(weather.temperature)} • ${weather.condition}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  'HOURLY FORECAST',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (weather.hourly.isNotEmpty)
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: weather.hourly.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final h = weather.hourly[index];
                        final hourStr = '${h.time.hour.toString().padLeft(2, '0')}:00';
                        return Container(
                          width: 64,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                hourStr,
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                              Icon(h.icon, color: Colors.white, size: 20),
                              Text(
                                _weatherService.formatTemp(h.temperature),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDetailPill('Humidity', '${weather.humidity}%', Icons.water_drop_outlined),
                    _buildDetailPill('Wind', '${weather.windSpeed.round()} km/h', Icons.air),
                    _buildDetailPill('Feels Like', _weatherService.formatTemp(weather.apparentTemperature), Icons.thermostat_outlined),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailPill(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _weatherService,
      builder: (context, _) {
        final weather = _weatherService.currentWeather;

        final tempString = weather != null
            ? _weatherService.formatTemp(weather.temperature)
            : '26°';
        final maxString = weather != null
            ? _weatherService.formatTemp(weather.maxTemperature)
            : '32°';
        final minString = weather != null
            ? _weatherService.formatTemp(weather.minTemperature)
            : '20°';
        final feelsString = weather != null
            ? _weatherService.formatTemp(weather.apparentTemperature)
            : '28°';
        final condition = weather?.condition ?? 'Partly cloudy';
        final cityName = weather?.cityName ?? 'CURRENT LOCATION';
        final iconData = weather?.icon ?? Icons.wb_cloudy;

        return GestureDetector(
          onTap: () {
            if (weather != null) {
              _showForecastSheet(context, weather);
            } else {
              _weatherService.fetchWeather(force: true);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tempString,
                          style: const TextStyle(
                            fontSize: 68,
                            fontWeight: FontWeight.w200,
                            color: Colors.white,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(iconData, color: Colors.white70, size: 28),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'H:$maxString L:$minString',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Feels like $feelsString',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white60,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      condition,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          cityName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_weatherService.isLoading) ...[
                          const SizedBox(width: 6),
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
