import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';

class OTPInputRow extends StatefulWidget {
  final int length;
  final Function(String) onCompleted;
  final bool hasError;

  const OTPInputRow({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.hasError = false,
  });

  @override
  State<OTPInputRow> createState() => _OTPInputRowState();
}

class _OTPInputRowState extends State<OTPInputRow> with SingleTickerProviderStateMixin {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(widget.length, (index) => FocusNode());
    _controllers = List.generate(widget.length, (index) => TextEditingController());
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 24.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void didUpdateWidget(OTPInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _shakeController.forward(from: 0.0).then((_) => _shakeController.reverse());
      // Clear OTP input on error
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _submit();
      }
    }
  }

  void _onKey(RawKeyEvent event, int index) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _submit() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * (1.0 - _shakeController.value), 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 8.0;
              final maxAvailable = (constraints.maxWidth - (widget.length - 1) * spacing) / widget.length;
              final boxWidth = maxAvailable.clamp(36.0, 48.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(widget.length, (index) {
                  return SizedBox(
                    width: boxWidth,
                    height: 56,
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (event) => _onKey(event, index),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                              color: Color(0xFF1E3A5F),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: widget.hasError
                                  ? AppColors.danger
                                  : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: widget.hasError
                                  ? AppColors.danger
                                  : const Color(0xFF1E3A5F),
                              width: 2.5,
                            ),
                          ),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        onChanged: (val) => _onChanged(val, index),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        );
      },
    );
  }
}
