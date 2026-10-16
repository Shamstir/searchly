import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final String condition;
  final IconData icon;

  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.condition,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'temperature': temperature,
        'condition': condition,
        'icon': icon.codePoint,
      };

  factory HourlyForecast.fromJson(Map<String, dynamic> json) => HourlyForecast(
        time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
        condition: json['condition'] ?? 'Clear',
        icon: IconData(json['icon'] as int? ?? Icons.wb_sunny.codePoint,
            fontFamily: 'MaterialIcons'),
      );
}

class WeatherData {
  final double temperature;
  final double apparentTemperature;
  final double maxTemperature;
  final double minTemperature;
  final int humidity;
  final double windSpeed;
  final String condition;
  final IconData icon;
  final String cityName;
  final DateTime timestamp;
  final List<HourlyForecast> hourly;

  const WeatherData({
    required this.temperature,
    required this.apparentTemperature,
    required this.maxTemperature,
    required this.minTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.icon,
    required this.cityName,
    required this.timestamp,
    required this.hourly,
  });

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'apparentTemperature': apparentTemperature,
        'maxTemperature': maxTemperature,
        'minTemperature': minTemperature,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'condition': condition,
        'icon': icon.codePoint,
        'cityName': cityName,
        'timestamp': timestamp.toIso8601String(),
        'hourly': hourly.map((h) => h.toJson()).toList(),
      };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        temperature: (json['temperature'] as num?)?.toDouble() ?? 25.0,
        apparentTemperature:
            (json['apparentTemperature'] as num?)?.toDouble() ?? 26.0,
        maxTemperature: (json['maxTemperature'] as num?)?.toDouble() ?? 28.0,
        minTemperature: (json['minTemperature'] as num?)?.toDouble() ?? 20.0,
        humidity: json['humidity'] as int? ?? 50,
        windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 10.0,
        condition: json['condition'] ?? 'Partly cloudy',
        icon: IconData(json['icon'] as int? ?? Icons.wb_cloudy.codePoint,
            fontFamily: 'MaterialIcons'),
        cityName: json['cityName'] ?? 'CURRENT LOCATION',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        hourly: (json['hourly'] as List<dynamic>?)
                ?.map((h) => HourlyForecast.fromJson(h as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class WeatherService extends ChangeNotifier {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const String _cacheKey = 'weather_cache_v2';
  static const String _unitKey = 'weather_unit_is_f';
  static const String _cityKey = 'weather_custom_city';

  WeatherData? _currentWeather;
  WeatherData? get currentWeather => _currentWeather;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isFahrenheit = false;
  bool get isFahrenheit => _isFahrenheit;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isFahrenheit = prefs.getBool(_unitKey) ?? false;
    final cachedJson = prefs.getString(_cacheKey);
    if (cachedJson != null) {
      try {
        _currentWeather = WeatherData.fromJson(jsonDecode(cachedJson));
        notifyListeners();
      } catch (e) {
        debugPrint('Failed to decode cached weather: $e');
      }
    }
    // Auto-fetch if cache is older than 30 mins or null
    if (_currentWeather == null ||
        DateTime.now().difference(_currentWeather!.timestamp).inMinutes > 30) {
      fetchWeather();
    }
  }

  Future<void> setUnitFahrenheit(bool useFahrenheit) async {
    _isFahrenheit = useFahrenheit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unitKey, useFahrenheit);
    notifyListeners();
  }

  Future<void> setCustomCity(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    if (cityName.trim().isEmpty) {
      await prefs.remove(_cityKey);
    } else {
      await prefs.setString(_cityKey, cityName.trim());
    }
    await fetchWeather(force: true);
  }

  Future<String?> getCustomCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cityKey);
  }

  double convertTemp(double celsius) {
    if (_isFahrenheit) {
      return (celsius * 9 / 5) + 32;
    }
    return celsius;
  }

  String formatTemp(double celsius) {
    final val = convertTemp(celsius);
    return '${val.round()}°';
  }

  static (String, IconData) _wmoCodeInfo(int code, bool isDay) {
    switch (code) {
      case 0:
        return (
          isDay ? 'Clear sky' : 'Clear night',
          isDay ? Icons.wb_sunny : Icons.nightlight_round
        );
      case 1:
      case 2:
      case 3:
        return (
          'Partly cloudy',
          isDay ? Icons.cloud_queue : Icons.nights_stay_outlined
        );
      case 45:
      case 48:
        return ('Foggy', Icons.foggy);
      case 51:
      case 53:
      case 55:
        return ('Drizzle', Icons.grain);
      case 61:
      case 63:
      case 65:
        return ('Rain', Icons.water_drop);
      case 71:
      case 73:
      case 75:
      case 77:
        return ('Snow', Icons.ac_unit);
      case 80:
      case 81:
      case 82:
        return ('Rain showers', Icons.shower);
      case 85:
      case 86:
        return ('Snow showers', Icons.snowshoeing);
      case 95:
      case 96:
      case 99:
        return ('Thunderstorm', Icons.thunderstorm);
      default:
        return ('Fair', Icons.wb_cloudy);
    }
  }

  Future<void> fetchWeather({bool force = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String? customCity = prefs.getString(_cityKey);

      double lat = 26.9124;
      double lon = 75.7873;
      String locationName = 'JAIPUR, IN';

      if (customCity != null && customCity.isNotEmpty) {
        // Geocode city name via Open-Meteo Geocoding API
        final geoUri = Uri.parse(
            'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(customCity)}&count=1&language=en&format=json');
        final geoRes = await http.get(geoUri).timeout(const Duration(seconds: 6));
        if (geoRes.statusCode == 200) {
          final geoData = jsonDecode(geoRes.body);
          final results = geoData['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            lat = (results[0]['latitude'] as num).toDouble();
            lon = (results[0]['longitude'] as num).toDouble();
            final name = results[0]['name'] ?? customCity;
            final country = results[0]['country_code'] ?? '';
            locationName = country.isNotEmpty
                ? '${name.toString().toUpperCase()}, ${country.toString().toUpperCase()}'
                : name.toString().toUpperCase();
          }
        }
      } else {
        // Auto-detect location via secure HTTPS IP Geolocation API
        bool detected = false;
        try {
          final ipUri = Uri.parse('https://freeipapi.com/api/json');
          final ipRes = await http.get(ipUri).timeout(const Duration(seconds: 4));
          if (ipRes.statusCode == 200) {
            final ipData = jsonDecode(ipRes.body);
            if (ipData is Map && ipData['latitude'] != null && ipData['longitude'] != null) {
              final rawLat = ipData['latitude'];
              final rawLon = ipData['longitude'];
              if (rawLat is num && rawLon is num) {
                lat = rawLat.toDouble();
                lon = rawLon.toDouble();
                final city = ipData['cityName'] ?? ipData['city'] ?? 'LOCATION';
                final country = ipData['countryCode'] ?? '';
                locationName = country.isNotEmpty
                    ? '${city.toString().toUpperCase()}, ${country.toString().toUpperCase()}'
                    : city.toString().toUpperCase();
                detected = true;
              }
            }
          }
        } catch (_) {}

        if (!detected) {
          try {
            final ipUri2 = Uri.parse('https://ipapi.co/json/');
            final ipRes2 = await http.get(ipUri2).timeout(const Duration(seconds: 4));
            if (ipRes2.statusCode == 200) {
              final ipData2 = jsonDecode(ipRes2.body);
              if (ipData2 is Map && ipData2['latitude'] != null && ipData2['longitude'] != null) {
                final rawLat = ipData2['latitude'];
                final rawLon = ipData2['longitude'];
                if (rawLat is num && rawLon is num) {
                  lat = rawLat.toDouble();
                  lon = rawLon.toDouble();
                  final city = ipData2['city'] ?? 'LOCATION';
                  final country = ipData2['country_code'] ?? '';
                  locationName = country.isNotEmpty
                      ? '${city.toString().toUpperCase()}, ${country.toString().toUpperCase()}'
                      : city.toString().toUpperCase();
                }
              }
            }
          } catch (_) {}
        }
      }

      final weatherUri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto');
      final res = await http.get(weatherUri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is! Map<String, dynamic>) return;
        final current = data['current'] as Map<String, dynamic>? ?? {};
        final daily = data['daily'] as Map<String, dynamic>? ?? {};
        final hourly = data['hourly'] as Map<String, dynamic>? ?? {};

        final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 20.0;
        final apparentTemp =
            (current['apparent_temperature'] as num?)?.toDouble() ?? temp;
        final humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 50;
        final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 5.0;
        final code = (current['weather_code'] as num?)?.toInt() ?? 0;
        final isDay = (current['is_day'] as num? ?? 1) == 1;

        final (condText, condIcon) = _wmoCodeInfo(code, isDay);

        final maxTemps = daily['temperature_2m_max'] as List<dynamic>? ?? [];
        final minTemps = daily['temperature_2m_min'] as List<dynamic>? ?? [];
        final maxTemp = (maxTemps.isNotEmpty && maxTemps[0] is num)
            ? (maxTemps[0] as num).toDouble()
            : temp + 4;
        final minTemp = (minTemps.isNotEmpty && minTemps[0] is num)
            ? (minTemps[0] as num).toDouble()
            : temp - 4;

        // Parse next 12 hours
        final List<HourlyForecast> hourlyList = [];
        final hourlyTimes = hourly['time'] as List<dynamic>? ?? [];
        final hourlyTemps = hourly['temperature_2m'] as List<dynamic>? ?? [];
        final hourlyCodes = hourly['weather_code'] as List<dynamic>? ?? [];

        final now = DateTime.now();
        int added = 0;
        for (int i = 0; i < hourlyTimes.length && added < 12; i++) {
          final t = DateTime.tryParse(hourlyTimes[i] ?? '');
          if (t != null && t.isAfter(now.subtract(const Duration(hours: 1)))) {
            final hCode = (hourlyCodes.length > i && hourlyCodes[i] is num)
                ? (hourlyCodes[i] as num).toInt()
                : 0;
            final hTemp = (hourlyTemps.length > i && hourlyTemps[i] is num)
                ? (hourlyTemps[i] as num).toDouble()
                : temp;
            final (hCond, hIcon) = _wmoCodeInfo(hCode, t.hour >= 6 && t.hour < 19);
            hourlyList.add(HourlyForecast(
              time: t,
              temperature: hTemp,
              condition: hCond,
              icon: hIcon,
            ));
            added++;
          }
        }

        _currentWeather = WeatherData(
          temperature: temp,
          apparentTemperature: apparentTemp,
          maxTemperature: maxTemp,
          minTemperature: minTemp,
          humidity: humidity,
          windSpeed: wind,
          condition: condText,
          icon: condIcon,
          cityName: locationName,
          timestamp: DateTime.now(),
          hourly: hourlyList,
        );

        await prefs.setString(_cacheKey, jsonEncode(_currentWeather!.toJson()));
      }
    } catch (e) {
      debugPrint('Weather fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
