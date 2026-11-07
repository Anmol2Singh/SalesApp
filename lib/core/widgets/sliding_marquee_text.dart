import 'package:flutter/material.dart';

/// A widget that displays text and, if it overflows its available width,
/// slides the text smoothly towards the left. When it reaches the end,
/// it pauses, blinks/fades back to the start, and repeats the cycle.
class SlidingMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final Duration blinkDuration;

  const SlidingMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(milliseconds: 1500),
    this.blinkDuration = const Duration(milliseconds: 200),
  });

  @override
  State<SlidingMarqueeText> createState() => _SlidingMarqueeTextState();
}

class _SlidingMarqueeTextState extends State<SlidingMarqueeText> {
  late final ScrollController _scrollController;
  bool _isAnimating = false;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimationIfNeeded());
  }

  @override
  void didUpdateWidget(SlidingMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimationIfNeeded());
    }
  }

  void _startAnimationIfNeeded() {
    if (!mounted || _isAnimating) return;
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 2) {
        _startCycle();
      }
    }
  }

  Future<void> _startCycle() async {
    if (_isAnimating || !mounted) return;
    _isAnimating = true;

    while (mounted) {
      // 1. Initial pause at the start
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_scrollController.hasClients) break;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 2) break;

      // 2. Slide smoothly towards left
      final durationMs = (maxScroll * 35).clamp(2000, 10000).toInt();
      try {
        await _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }

      // 3. Pause at last word
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_scrollController.hasClients) break;

      // 4. Blink / fade out
      if (mounted) setState(() => _opacity = 0.0);
      await Future.delayed(widget.blinkDuration);
      if (!mounted || !_scrollController.hasClients) break;

      // Jump to start while hidden
      _scrollController.jumpTo(0);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || !_scrollController.hasClients) break;

      // Blink / fade back in
      if (mounted) setState(() => _opacity = 1.0);
      await Future.delayed(const Duration(milliseconds: 150));
    }

    _isAnimating = false;
  }

  @override
  void dispose() {
    _isAnimating = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: widget.blinkDuration,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          maxLines: 1,
          style: widget.style,
        ),
      ),
    );
  }
}

