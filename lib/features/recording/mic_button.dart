import 'package:flutter/material.dart';

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
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: isRecording ? 120 : 108,
        height: isRecording ? 120 : 108,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.9),
          border: Border.all(
            color: isRecording ? primary : primary.withValues(alpha: 0.78),
            width: isRecording ? 8 : 4,
          ),
          gradient: LinearGradient(
            colors: [Colors.white, secondary.withValues(alpha: 0.18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: isRecording ? 32 : 18,
              color: primary.withValues(alpha: isRecording ? 0.24 : 0.12),
              spreadRadius: isRecording ? 6 : 0,
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop_rounded : Icons.mic,
          color: primary,
          size: 42,
        ),
      ),
    );
  }
}
