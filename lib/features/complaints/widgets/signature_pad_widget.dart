// lib/features/complaints/widgets/signature_pad_widget.dart

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SignaturePadDialog extends StatefulWidget {
  final String title;
  const SignaturePadDialog({super.key, this.title = 'Customer Signature'});

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<Offset?> _points = [];

  void _clear() {
    setState(() {
      _points.clear();
    });
  }

  Future<String?> _captureSignature() async {
    final validPoints = _points.whereType<Offset>().toList();
    if (validPoints.isEmpty) return null;

    double minX = validPoints.first.dx;
    double maxX = validPoints.first.dx;
    double minY = validPoints.first.dy;
    double maxY = validPoints.first.dy;

    for (final p in validPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    // Add breathing margin around drawn signature
    const margin = 16.0;
    minX = (minX - margin);
    minY = (minY - margin);
    maxX = (maxX + margin);
    maxY = (maxY + margin);

    final drawnWidth = (maxX - minX).clamp(40.0, 5000.0);
    final drawnHeight = (maxY - minY).clamp(30.0, 3000.0);

    // Target crisp canvas dimensions for high quality PDF & screen export
    const double targetWidth = 500.0;
    final double targetHeight = (targetWidth * (drawnHeight / drawnWidth)).clamp(150.0, 300.0);

    final scaleX = targetWidth / drawnWidth;
    final scaleY = targetHeight / drawnHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final renderedW = drawnWidth * scale;
    final renderedH = drawnHeight * scale;
    final offsetX = (targetWidth - renderedW) / 2.0 - (minX * scale);
    final offsetY = (targetHeight - renderedH) / 2.0 - (minY * scale);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw solid white background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, targetWidth, targetHeight), bgPaint);

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);

    // Draw signature lines with crisp adaptive stroke width
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.5 / scale;

    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != null && _points[i + 1] != null) {
        canvas.drawLine(_points[i]!, _points[i + 1]!, paint);
      }
    }
    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(targetWidth.toInt(), targetHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    final base64Str = base64Encode(bytes);
    return 'data:image/png;base64,$base64Str';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            tooltip: 'Clear Signature',
            onPressed: _clear,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Please request customer to sign inside the box below:',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            width: double.maxFinite,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6D28D9), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _points.add(details.localPosition);
                  });
                },
                onPanEnd: (details) {
                  _points.add(null);
                },
                child: CustomPaint(
                  painter: _SignaturePainter(_points),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6D28D9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.check, color: Colors.white, size: 18),
          label: const Text('Save Signature', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: () async {
            if (_points.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please draw signature first!'), backgroundColor: Colors.orange),
              );
              return;
            }
            final sig = await _captureSignature();
            if (mounted) Navigator.pop(context, sig);
          },
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
