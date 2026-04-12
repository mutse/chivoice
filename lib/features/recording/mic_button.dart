import 'package:flutter/material.dart';

import '../shared/theme.dart';

class MicButton extends StatelessWidget {
  const MicButton({
    super.key,
    required this.isRecording,
    required this.onPressed,
  });

  final bool isRecording;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: isRecording ? 112 : 96,
        height: isRecording ? 112 : 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [kPurple400, kPurple600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: isRecording ? 32 : 16,
              color: kPurple400.withValues(alpha: isRecording ? 0.55 : 0.25),
              spreadRadius: isRecording ? 6 : 0,
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop_rounded : Icons.mic,
          color: Colors.white,
          size: 38,
        ),
      ),
    );
  }
}
