/// Small formatting helpers shared by screens.
String prettyId(String id) => id
    .split('_')
    .where((String p) => p.isNotEmpty)
    .map((String p) => '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

String percent(double value, {int decimals = 1}) => '${(value * 100).toStringAsFixed(decimals)}%';
