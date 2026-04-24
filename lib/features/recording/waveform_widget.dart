import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class WaveformWidget extends StatefulWidget {
  const WaveformWidget({
    super.key,
    required this.amplitudeStream,
    this.barCount = 30,
    required this.activeColor,
  });

  final Stream<double> amplitudeStream;
  final int barCount;
  final Color activeColor;

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget> {
  late final List<double> _factors = List<double>.generate(
    widget.barCount,
    (index) => 0.45 + Random(index * 13 + 7).nextDouble() * 0.75,
  );
  late final List<double> _heights = List<double>.filled(
    widget.barCount,
    4,
    growable: false,
  );
  StreamSubscription<double>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.amplitudeStream.listen((amplitude) {
      if (!mounted) {
        return;
      }
      setState(() {
        for (var i = 0; i < _heights.length; i++) {
          _heights[i] = 4 + (72 * amplitude * _factors[i]);
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _heights
            .map(
              (height) => AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 5,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      widget.activeColor.withValues(alpha: 0.55),
                      widget.activeColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
