import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'bounce_button.dart';
import '../../data/services/calculator_parser.dart';

class FloatingCalculator extends StatefulWidget {
  final VoidCallback onClose;
  const FloatingCalculator({super.key, required this.onClose});

  @override
  State<FloatingCalculator> createState() => _FloatingCalculatorState();
}

class _FloatingCalculatorState extends State<FloatingCalculator> {
  Offset _position = const Offset(40, 100);
  String _input = '';
  String _result = '';
  bool _isScientific = false;

  void _onKeyPress(String value) {
    setState(() {
      if (value == 'C') {
        _input = '';
        _result = '';
      } else if (value == '⌫') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
      } else if (value == '=') {
        _calculate();
      } else {
        _input += value;
      }
    });
  }

  void _calculate() {
    if (_input.isEmpty) return;
    try {
      final res = CalculatorParser.evaluate(_input, isDegree: true);
      if (res.isNaN || res.isInfinite) {
        _result = 'Hata';
      } else {
        // Format result: if it has .0, remove it
        if (res == res.toInt()) {
          _result = res.toInt().toString();
        } else {
          _result = res.toStringAsFixed(4);
          // Trim trailing zeroes
          while (_result.endsWith('0')) {
            _result = _result.substring(0, _result.length - 1);
          }
          if (_result.endsWith('.')) {
            _result = _result.substring(0, _result.length - 1);
          }
        }
      }
    } catch (_) {
      _result = 'Hata';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = _isScientific ? 360.0 : 250.0;
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          final size = MediaQuery.of(context).size;
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(10.0, size.width - width - 20.0),
              (_position.dy + details.delta.dy).clamp(50.0, size.height - 390.0),
            );
          });
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.neonBlue.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: AppTheme.neonBlueGlow(intensity: 0.25),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Titlebar / Drag Handle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCardHigh.withOpacity(0.4),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calculate_rounded, size: 16, color: AppTheme.neonBlue),
                        const SizedBox(width: 8),
                        Text(
                          'Hesap Makinesi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Scientific mode toggle button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isScientific = !_isScientific;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isScientific 
                                  ? AppTheme.neonPurple.withOpacity(0.2) 
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isScientific 
                                    ? AppTheme.neonPurple.withOpacity(0.5) 
                                    : AppTheme.textMuted.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Bilimsel',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _isScientific ? AppTheme.neonPurple : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Display Area
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.black.withOpacity(0.2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _input.isEmpty ? '0' : _input,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _result.isEmpty ? ' ' : _result,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neonAccent,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Keypad + Side Scientific Panel
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isScientific)
                        Container(
                          width: 110,
                          padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 6,
                            childAspectRatio: 1.2,
                            children: [
                              _buildButton('sin('),
                              _buildButton('cos('),
                              _buildButton('tan('),
                              _buildButton('cot('),
                              _buildButton('log('),
                              _buildButton('ln('),
                              _buildButton('√('),
                              _buildButton('^'),
                              _buildButton('π'),
                              _buildButton('e'),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 4,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: _isScientific ? 1.0 : 1.35,
                            children: [
                              _buildButton('C', color: AppTheme.errorRed),
                              _buildButton('(', color: AppTheme.neonPurple),
                              _buildButton(')', color: AppTheme.neonPurple),
                              _buildButton('÷', color: AppTheme.neonPurple),

                              _buildButton('7'),
                              _buildButton('8'),
                              _buildButton('9'),
                              _buildButton('×', color: AppTheme.neonPurple),

                              _buildButton('4'),
                              _buildButton('5'),
                              _buildButton('6'),
                              _buildButton('-', color: AppTheme.neonPurple),

                              _buildButton('1'),
                              _buildButton('2'),
                              _buildButton('3'),
                              _buildButton('+', color: AppTheme.neonPurple),

                              _buildButton('0'),
                              _buildButton('.'),
                              _buildButton('⌫', color: AppTheme.textSecondary),
                              _buildButton('=', color: AppTheme.neonBlue, isPrimary: true),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, {Color? color, bool isPrimary = false}) {
    final textColor = isPrimary
        ? Colors.white
        : (color ?? AppTheme.textPrimary);

    return BounceButton(
      onTap: () => _onKeyPress(text),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPrimary
              ? (color ?? AppTheme.neonBlue)
              : AppTheme.darkCardHigh.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : AppTheme.textMuted.withOpacity(0.15),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: text.length > 2 ? 11 : 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
