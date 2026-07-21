import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/services/calculator_parser.dart';
import '../../../application/providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bounce_button.dart';
import '../../widgets/fade_slide_entrance.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = '';
  String _result = '0';
  String _errorMessage = '';
  bool _isDegree = true;

  void _onKeyPress(String value) {
    setState(() {
      _errorMessage = '';
      if (value == 'AC') {
        _expression = '';
        _result = '0';
      } else if (value == 'C') {
        if (_expression.isNotEmpty) {
          bool deletedFunc = false;
          final funcs = ['sin(', 'cos(', 'tan(', 'cot(', 'log(', 'ln(', 'sqrt('];
          for (final f in funcs) {
            if (_expression.endsWith(f)) {
              _expression = _expression.substring(0, _expression.length - f.length);
              deletedFunc = true;
              break;
            }
          }
          if (!deletedFunc) {
            _expression = _expression.substring(0, _expression.length - 1);
          }
        }
      } else if (value == '=') {
        _evaluate();
      } else {
        if (value == 'sin' || value == 'cos' || value == 'tan' || value == 'cot' ||
            value == 'log' || value == 'ln' || value == '√') {
          final funcMap = {
            'sin': 'sin(',
            'cos': 'cos(',
            'tan': 'tan(',
            'cot': 'cot(',
            'log': 'log(',
            'ln': 'ln(',
            '√': '√(',
          };
          _expression += funcMap[value]!;
        } else {
          _expression += value;
        }
      }

      if (_expression.isNotEmpty && value != '=') {
        _autoEvaluate();
      } else if (_expression.isEmpty) {
        _result = '0';
      }
    });
  }

  void _evaluate() {
    if (_expression.isEmpty) return;
    try {
      final res = CalculatorParser.evaluate(_expression, isDegree: _isDegree);
      setState(() {
        if (res.isInfinite || res.isNaN) {
          _result = 'Hata';
        } else {
          _result = _formatResult(res);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _autoEvaluate() {
    try {
      String tempExpr = _expression;
      int openParens = '('.allMatches(tempExpr).length;
      int closeParens = ')'.allMatches(tempExpr).length;
      if (openParens > closeParens) {
        tempExpr += ')' * (openParens - closeParens);
      }
      final res = CalculatorParser.evaluate(tempExpr, isDegree: _isDegree);
      if (!res.isInfinite && !res.isNaN) {
        setState(() {
          _result = _formatResult(res);
        });
      }
    } catch (_) {}
  }

  String _formatResult(double val) {
    if (val == val.toInt()) return val.toInt().toString();
    String str = val.toStringAsFixed(8);
    while (str.endsWith('0')) {
      str = str.substring(0, str.length - 1);
    }
    if (str.endsWith('.')) str = str.substring(0, str.length - 1);
    return str;
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧮 Hesap Makinesi Hakkında'),
        content: const SingleChildScrollView(
          child: Text(
            'Bilimsel Hesap Makinesi modülü, ders çalışırken ve not alırken ihtiyaç duyduğunuz tüm matematiksel hesaplamaları hızlıca çözmenize yardımcı olur.\n\n'
            'Nasıl Kullanılır?\n'
            '1. Temel İşlemler: Toplama, çıkarma, çarpma, bölme işlemlerini standart tuşlarla gerçekleştirin.\n'
            '2. Gelişmiş Bilimsel İşlemler: Üst paneldeki sin, cos, tan, cot, log, ln, karekök (√), pi (π) ve e sayısı ile üs alma (^) gibi gelişmiş bilimsel ve trigonometrik formülleri parantezli şekilde girip hesaplayabilirsiniz.\n'
            '3. Derece/Radyan: Sol üstteki derece/radyan anahtarıyla trigonometri ölçü birimlerini belirleyin.',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final List<List<String>> buttons = [
      ['sin', 'cos', 'tan', 'cot', 'log'],
      ['ln', '√', '^', '(', ')'],
      ['7', '8', '9', '÷', 'C'],
      ['4', '5', '6', '×', 'AC'],
      ['1', '2', '3', '-', 'e'],
      ['0', '.', 'π', '+', '='],
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧮 Bilimsel Hesap Makinesi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Bilgi',
            onPressed: _showInfoDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.darkCard, AppTheme.darkBg, AppTheme.darkBgDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FadeSlideEntrance(
          delay: const Duration(milliseconds: 100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalHeight = constraints.maxHeight;
              final displayHeight = totalHeight * 0.28;
              const toggleHeight = 44.0;
              final buttonsHeight = totalHeight - displayHeight - toggleHeight - 16.0;

              const double gapHeight = 6.0;
              final double dynamicButtonHeight =
                  ((buttonsHeight - (5 * gapHeight)) / 6.0).clamp(40.0, 58.0);

              return Column(
                children: [
                  // ── Display Panel ─────────────────────────────────
                  Container(
                    height: displayHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.neonBlue.withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.neonBlue.withValues(alpha: 0.08),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                          ...AppTheme.cardShadow,
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Expression
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            child: Text(
                              _expression.isEmpty ? ' ' : _expression,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.textSecondary,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Error
                          if (_errorMessage.isNotEmpty)
                            Text(
                              _errorMessage,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.errorRed,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.right,
                            )
                          else
                            const SizedBox(height: 10),
                          // Result — neon gradient text
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: ShaderMask(
                                shaderCallback: (bounds) =>
                                    AppTheme.primaryGradient.createShader(bounds),
                                blendMode: BlendMode.srcIn,
                                child: Text(
                                  _result,
                                  style: const TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── DEG/RAD Toggle ────────────────────────────────
                  SizedBox(
                    height: toggleHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.darkCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.textMuted.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildToggleSegment('DEG (Derece)', _isDegree, () {
                                  setState(() {
                                    _isDegree = true;
                                    if (_expression.isNotEmpty) _evaluate();
                                  });
                                }),
                                _buildToggleSegment('RAD (Radyan)', !_isDegree, () {
                                  setState(() {
                                    _isDegree = false;
                                    if (_expression.isNotEmpty) _evaluate();
                                  });
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Button Grid ───────────────────────────────────
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12, top: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: buttons.map((row) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: row.map((btn) {
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                  child: _buildButton(btn, dynamicButtonHeight),
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSegment(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String symbol, double buttonHeight) {
    final bool isNumber = RegExp(r'^\d$|\.').hasMatch(symbol);
    final bool isBasicOp = ['+', '-', '×', '÷'].contains(symbol);
    final bool isConstant = ['π', 'e', '(', ')'].contains(symbol);

    // Resolve button style
    final bool isEquals = symbol == '=';
    final bool isClear = symbol == 'AC';
    final bool isBackspace = symbol == 'C';

    Widget buttonChild;
    BoxDecoration decoration;

    if (isEquals) {
      // Primary gradient = button with glow
      decoration = BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.primaryGlow(intensity: 0.5),
      );
      buttonChild = const Text(
        '=',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    } else if (isClear) {
      decoration = BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.35)),
      );
      buttonChild = Text('AC',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.errorRed));
    } else if (isBackspace) {
      decoration = BoxDecoration(
        color: AppTheme.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningAmber.withValues(alpha: 0.30)),
      );
      buttonChild = Text('C',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.warningAmber));
    } else if (isNumber) {
      decoration = BoxDecoration(
        color: AppTheme.darkCardHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.15)),
      );
      buttonChild = Text(
        symbol,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      );
    } else if (isBasicOp) {
      decoration = BoxDecoration(
        color: AppTheme.neonBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neonBlue.withValues(alpha: 0.30)),
      );
      buttonChild = Text(
        symbol,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.neonAccent,
        ),
      );
    } else if (isConstant) {
      decoration = BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.18)),
      );
      buttonChild = Text(
        symbol,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      );
    } else {
      // Scientific functions — neon purple tint
      decoration = BoxDecoration(
        color: AppTheme.neonPurple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.28)),
      );
      buttonChild = Text(
        symbol,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFB39DFF), // Light purple text
        ),
      );
    }

    return BounceButton(
      onTap: () => _onKeyPress(symbol),
      child: Container(
        height: buttonHeight,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: decoration,
        child: Center(child: buttonChild),
      ),
    );
  }
}
