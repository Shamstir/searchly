import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:searchly/widgets/search_bar_widget.dart';
import 'package:searchly/widgets/custom_widget_container.dart';
import 'package:searchly/widgets/custom_widgets/app_shortcuts_widget.dart';
import 'package:searchly/widgets/custom_widgets/todo_list_widget.dart';
import 'package:searchly/widgets/custom_widgets/system_control_widget.dart';
import 'package:searchly/widgets/custom_widgets/music_player_widget.dart';
import 'package:searchly/widgets/custom_widgets/image_gallery_widget.dart';
import 'package:searchly/widgets/custom_widgets/screen_time_widget.dart';
import 'package:searchly/widgets/custom_widgets/weather_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Widget> widgetsOnCanvas;

  @override
  void initState() {
    super.initState();
    // Initialize widgets in the order they should appear in the flow
    widgetsOnCanvas = [
      const CustomWidgetContainer(
        initialWidth: 350,
        initialHeight: 180,
        child: WeatherWidget(),
      ),
      const CustomWidgetContainer(
        initialWidth: 170,
        initialHeight: 260,
        child: MusicPlayerWidget(),
      ),
      const CustomWidgetContainer(
        initialWidth: 170,
        initialHeight: 260,
        child: ImageGalleryWidget(),
      ),
      const CustomWidgetContainer(
        initialWidth: 350,
        initialHeight: 180,
        child: SystemControlWidget(),
      ),
      const CustomWidgetContainer(
        initialWidth: 170,
        initialHeight: 220,
        child: TodoListWidget(),
      ),
      const CustomWidgetContainer(
        initialWidth: 170,
        initialHeight: 220,
        child: ScreenTimeWidget(),
      ),
      const CustomWidgetContainer(
        initialWidth: 350,
        initialHeight: 140,
        child: AppShortcutsWidget(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2EE), // Paper ink light beige
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16, bottom: 100, left: 12, right: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: widgetsOnCanvas,
              ),
            ),
            
            // Bottom Search Bar
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
                child: SearchBarWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
