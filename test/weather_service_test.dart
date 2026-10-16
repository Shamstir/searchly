import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:searchly/services/weather_service.dart';

void main() {
  group('WeatherService Model & Conversion Tests', () {
    test('Temperature conversion math is accurate', () {
      final service = WeatherService();
      expect(service.convertTemp(0), 0); // Default Celsius
      expect(service.formatTemp(25), '25°');
    });

    test('WeatherData serializes and deserializes properly', () {
      final now = DateTime.now();
      final data = WeatherData(
        temperature: 28.5,
        apparentTemperature: 31.0,
        maxTemperature: 34.0,
        minTemperature: 22.0,
        humidity: 45,
        windSpeed: 12.0,
        condition: 'Clear sky',
        icon: Icons.wb_sunny,
        cityName: 'JAIPUR, IN',
        timestamp: now,
        hourly: [
          HourlyForecast(
            time: now,
            temperature: 28.5,
            condition: 'Clear sky',
            icon: Icons.wb_sunny,
          ),
        ],
      );

      final json = data.toJson();
      expect(json['temperature'], 28.5);
      expect(json['cityName'], 'JAIPUR, IN');
      expect(json['hourly'].length, 1);

      final restored = WeatherData.fromJson(json);
      expect(restored.temperature, 28.5);
      expect(restored.cityName, 'JAIPUR, IN');
      expect(restored.hourly.length, 1);
      expect(restored.hourly.first.condition, 'Clear sky');
    });
  });
}
