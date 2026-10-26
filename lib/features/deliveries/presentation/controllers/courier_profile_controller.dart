import 'package:flutter/foundation.dart';

import '../../../../core/texts/app_texts.dart';
import '../../data/courier_profile_api.dart';
import '../../domain/courier_account.dart';

class CourierProfileController extends ChangeNotifier {
  CourierProfileController({CourierProfileApi api = const CourierProfileApi()})
    : _api = api;

  final CourierProfileApi _api;
  bool _disposed = false;
  int _generation = 0;

  CourierAccount? _account;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  Future<void>? _loadInFlight;

  CourierAccount? get account => _account;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  Future<void> loadAccountIfNeeded() async {
    if (_hasLoaded || _disposed) return;
    await loadAccount();
  }

  Future<void> loadAccount() async {
    if (_disposed) return;
    final activeLoad = _loadInFlight;
    if (activeLoad != null) return activeLoad;

    final loadFuture = _loadAccount();
    _loadInFlight = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_loadInFlight, loadFuture)) {
        _loadInFlight = null;
      }
    }
  }

  Future<void> refresh() => loadAccount();

  Future<void> _loadAccount() async {
    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final account = await _api.loadAccount();
      if (_disposed || generation != _generation) return;
      _account = account;
      _hasLoaded = true;
      _errorMessage = null;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _errorMessage = _arabicError(error);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  String _arabicError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return ProfileTexts.loadFailedRetry;
    }
    return message;
  }
}
