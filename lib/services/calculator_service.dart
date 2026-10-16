import 'dart:math' as math;

/// Evaluates mathematical expressions typed into the Omnibar.
class CalculatorService {
  CalculatorService._();
  static final CalculatorService instance = CalculatorService._();

  /// Checks if a string looks like a mathematical expression.
  static bool isLikelyMath(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    // Check if input starts with 'calc '
    if (trimmed.toLowerCase().startsWith('calc ')) return true;

    // Must contain numbers and at least one math operator or known math function
    final hasNumber = RegExp(r'\d').hasMatch(trimmed);
    final hasOperator = RegExp(r'[+\-*/%^=]').hasMatch(trimmed) ||
        RegExp(r'\b(sqrt|sin|cos|tan|log|ln|abs|pi|e)\b', caseSensitive: false)
            .hasMatch(trimmed);

    // Filter out common commands or words that aren't math
    final isWordCommand = RegExp(r'^(call|alarm|wm|msg|timer|wa|open|search)\b',
            caseSensitive: false)
        .hasMatch(trimmed);

    // If it has letters, ensure they are strictly math functions/constants
    final cleanedFromMath = trimmed
        .replaceAll(RegExp(r'\b(calc|sqrt|sin|cos|tan|log|ln|abs|pi|e|of)\b',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'[0-9\s+\-*/%^().,]'), '');

    return hasNumber && hasOperator && !isWordCommand && cleanedFromMath.isEmpty;
  }

  /// Evaluates the math string and returns a formatted result, or null if invalid.
  static String? evaluate(String expression) {
    try {
      var exp = expression.trim();
      if (exp.toLowerCase().startsWith('calc ')) {
        exp = exp.substring(5).trim();
      }
      if (exp.isEmpty) return null;

      // Handle "X% of Y" -> (X / 100) * Y
      final percentOfRegex = RegExp(
          r'([\d.]+)\s*%\s*(?:of|\*)\s*([\d.]+)', caseSensitive: false);
      exp = exp.replaceAllMapped(percentOfRegex, (m) {
        final p = double.tryParse(m.group(1) ?? '') ?? 0;
        final v = double.tryParse(m.group(2) ?? '') ?? 0;
        return ((p / 100) * v).toString();
      });

      // Handle trailing percentage: "X%" -> (X / 100)
      exp = exp.replaceAllMapped(RegExp(r'([\d.]+)\s*%'), (m) {
        final p = double.tryParse(m.group(1) ?? '') ?? 0;
        return (p / 100).toString();
      });

      // Normalize constants
      exp = exp
          .replaceAll(RegExp(r'\bpi\b', caseSensitive: false), '${math.pi}')
          .replaceAll(RegExp(r'\be\b', caseSensitive: false), '${math.e}');

      final parser = _Parser(exp);
      final val = parser.parse();

      if (val.isNaN || val.isInfinite) return null;

      // Nicely format the result
      if (val == val.roundToDouble() && val.abs() < 1e12) {
        return val.toInt().toString();
      }
      // Trim precision to at most 6 decimal places
      final formatted = val.toStringAsFixed(6);
      return formatted.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    } catch (_) {
      return null;
    }
  }
}

class _Parser {
  final String text;
  int _pos = -1;
  int _ch = -1;

  _Parser(this.text);

  void _nextChar() {
    _pos++;
    _ch = _pos < text.length ? text.codeUnitAt(_pos) : -1;
  }

  bool _eat(int charToEat) {
    while (_ch == 32) {
      _nextChar(); // skip spaces
    }
    if (_ch == charToEat) {
      _nextChar();
      return true;
    }
    return false;
  }

  double parse() {
    _nextChar();
    final x = _parseExpression();
    while (_ch == 32) {
      _nextChar();
    }
    if (_pos < text.length) throw FormatException('Unexpected: ${_pos < text.length ? text[_pos] : ""}');
    return x;
  }

  double _parseExpression() {
    var x = _parseTerm();
    for (;;) {
      if (_eat(43)) {
        // '+'
        x += _parseTerm();
      } else if (_eat(45)) {
        // '-'
        x -= _parseTerm();
      } else {
        return x;
      }
    }
  }

  double _parseTerm() {
    var x = _parseFactor();
    for (;;) {
      if (_eat(42) || _eat(120) || _eat(88)) {
        // '*', 'x', 'X'
        x *= _parseFactor();
      } else if (_eat(47)) {
        // '/'
        final divisor = _parseFactor();
        if (divisor == 0) throw const FormatException('Division by zero');
        x /= divisor;
      } else if (_eat(37)) {
        // '%'
        final divisor = _parseFactor();
        x %= divisor;
      } else {
        return x;
      }
    }
  }

  double _parseFactor() {
    if (_eat(43)) return _parseFactor(); // unary +
    if (_eat(45)) return -_parseFactor(); // unary -

    double x;
    final startPos = _pos;

    if (_eat(40)) {
      // '('
      x = _parseExpression();
      _eat(41); // ')'
    } else if ((_ch >= 48 && _ch <= 57) || _ch == 46) {
      // numbers 0-9 or .
      while ((_ch >= 48 && _ch <= 57) || _ch == 46) {
        _nextChar();
      }
      x = double.parse(text.substring(startPos, _pos));
    } else if (_ch >= 97 && _ch <= 122) {
      // functions
      while (_ch >= 97 && _ch <= 122) {
        _nextChar();
      }
      final func = text.substring(startPos, _pos).toLowerCase();
      x = _parseFactor();
      if (func == 'sqrt') {
        x = math.sqrt(x);
      } else if (func == 'sin') {
        x = math.sin(x * (math.pi / 180));
      } else if (func == 'cos') {
        x = math.cos(x * (math.pi / 180));
      } else if (func == 'tan') {
        x = math.tan(x * (math.pi / 180));
      } else if (func == 'log') {
        x = math.log(x) / math.ln10;
      } else if (func == 'ln') {
        x = math.log(x);
      } else if (func == 'abs') {
        x = x.abs();
      } else {
        throw FormatException('Unknown function: $func');
      }
    } else {
      throw const FormatException('Unexpected token');
    }

    if (_eat(94)) {
      // '^' power
      x = math.pow(x, _parseFactor()).toDouble();
    }

    return x;
  }
}
