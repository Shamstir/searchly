import 'package:flutter/material.dart';

class CustomWidgetContainer extends StatefulWidget {
  final Widget child;
  final double initialWidth;
  final double initialHeight;
  final Function(double width, double height)? onUpdate;

  const CustomWidgetContainer({
    super.key,
    required this.child,
    this.initialWidth = 160,
    this.initialHeight = 160,
    this.onUpdate,
  });

  @override
  State<CustomWidgetContainer> createState() => _CustomWidgetContainerState();
}

class _CustomWidgetContainerState extends State<CustomWidgetContainer> {
  late double width;
  late double height;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    width = widget.initialWidth;
    height = widget.initialHeight;
  }

  void _notifyUpdate() {
    if (widget.onUpdate != null) {
      widget.onUpdate!(width, height);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        setState(() {
          isEditing = !isEditing;
        });
      },
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.transparent, // Background handled by child
          borderRadius: BorderRadius.circular(24),
          border: isEditing ? Border.all(color: Colors.black26, width: 2) : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (isEditing)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      width = (width + details.delta.dx).clamp(80.0, 400.0);
                      height = (height + details.delta.dy).clamp(80.0, 600.0);
                    });
                    _notifyUpdate();
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: const Icon(Icons.open_in_full, size: 16, color: Colors.white),
                  ),
                ),
              ),
            if (isEditing)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.black),
                  onPressed: () {
                    setState(() {
                      isEditing = false;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
