import 'dart:math' as math;

class CalculatorParser {
  /// Evaluates a mathematical expression and returns the double result.
  /// Throws an [Exception] if the expression is invalid.
  static double evaluate(String expression, {bool isDegree = true}) {
    // Standardize input string
    String expr = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('π', 'pi')
        .replaceAll('√', 'sqrt')
        .replaceAll(' ', ''); // Remove all spaces

    if (expr.isEmpty) return 0.0;

    int pos = -1;
    int ch = -1;

    void nextChar() {
      pos++;
      ch = (pos < expr.length) ? expr.codeUnitAt(pos) : -1;
    }

    bool eat(int charToEat) {
      while (ch == 32) { // Space
        nextChar();
      }
      if (ch == charToEat) {
        nextChar();
        return true;
      }
      return false;
    }

    bool isMultipleOf(double value, double divisor) {
      double ratio = value / divisor;
      return (ratio - ratio.round()).abs() < 1e-9;
    }

    late double Function() parseExpression;
    late double Function() parseTerm;
    late double Function() parseFactor;

    // Expression parser (addition and subtraction)
    parseExpression = () {
      double x = parseTerm();
      for (;;) {
        if (eat(43)) { // '+'
          x += parseTerm();
        } else if (eat(45)) { // '-'
          x -= parseTerm();
        } else {
          return x;
        }
      }
    };

    // Term parser (multiplication and division)
    parseTerm = () {
      double x = parseFactor();
      for (;;) {
        if (eat(42)) { // '*'
          x *= parseFactor();
        } else if (eat(47)) { // '/'
          double divisor = parseFactor();
          if (divisor == 0) throw Exception('Sıfıra bölme hatası');
          x /= divisor;
        } else {
          return x;
        }
      }
    };

    // Factor parser (numbers, parentheses, functions, exponent)
    parseFactor = () {
      if (eat(43)) return parseFactor(); // unary plus
      if (eat(45)) return -parseFactor(); // unary minus

      double x;
      int startPos = pos;
      if (eat(40)) { // '('
        x = parseExpression();
        if (!eat(41)) throw Exception('Eksik parantez \')\'');
      } else if ((ch >= 48 && ch <= 57) || ch == 46) { // numbers: 0-9 or .
        while ((ch >= 48 && ch <= 57) || ch == 46) {
          nextChar();
        }
        x = double.parse(expr.substring(startPos, pos));
      } else if (ch >= 97 && ch <= 122) { // letters (functions or constants)
        while (ch >= 97 && ch <= 122) {
          nextChar();
        }
        String func = expr.substring(startPos, pos);
        if (func == 'pi') {
          x = math.pi;
        } else if (func == 'e') {
          x = math.e;
        } else {
          // Functions must be followed by a parenthesis
          if (!eat(40)) throw Exception('$func sonrası \'(\' bekleniyor');
          double arg = parseExpression();
          if (!eat(41)) throw Exception('$func için eksik parantez \')\'');
          
          if (func == 'sin') {
            double val = isDegree ? (arg * math.pi / 180.0) : arg;
            x = math.sin(val);
          } else if (func == 'cos') {
            double val = isDegree ? (arg * math.pi / 180.0) : arg;
            x = math.cos(val);
            if (isDegree && isMultipleOf(arg - 90, 180)) {
              x = 0.0;
            }
          } else if (func == 'tan') {
            double val = isDegree ? (arg * math.pi / 180.0) : arg;
            if (isDegree && isMultipleOf(arg - 90, 180)) {
              throw Exception('tan için tanımsız değer');
            }
            x = math.tan(val);
          } else if (func == 'cot') {
            double val = isDegree ? (arg * math.pi / 180.0) : arg;
            if (isDegree && isMultipleOf(arg, 180)) {
              throw Exception('cot için tanımsız değer');
            }
            double tanVal = math.tan(val);
            if (tanVal == 0) {
              throw Exception('cot için tanımsız değer');
            }
            x = 1.0 / tanVal;
          } else if (func == 'log') {
            if (arg <= 0) throw Exception('Geçersiz logaritma girdisi');
            x = math.log(arg) / math.ln10; // log base 10
          } else if (func == 'ln') {
            if (arg <= 0) throw Exception('Geçersiz ln girdisi');
            x = math.log(arg); // natural log
          } else if (func == 'sqrt') {
            if (arg < 0) throw Exception('Negatif sayı karekök hatası');
            x = math.sqrt(arg);
          } else {
            throw Exception('Bilinmeyen fonksiyon: $func');
          }
        }
      } else {
        throw Exception('Geçersiz karakter: ${String.fromCharCode(ch == -1 ? 63 : ch)}');
      }

      if (eat(94)) { // '^' exponent
        x = math.pow(x, parseFactor()).toDouble();
      }

      return x;
    };

    nextChar();
    double result = parseExpression();
    if (pos < expr.length) {
      // Allow trailing expression evaluation or error out
      throw Exception('İfade sonlandırılamadı: ${expr.substring(pos)}');
    }
    return result;
  }
}
