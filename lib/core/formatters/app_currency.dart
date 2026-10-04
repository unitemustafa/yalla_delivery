import '../texts/app_texts.dart';

class AppCurrency {
  AppCurrency._();

  static String format(num value) {
    final rounded = value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    return CurrencyTexts.pounds(rounded);
  }
}
