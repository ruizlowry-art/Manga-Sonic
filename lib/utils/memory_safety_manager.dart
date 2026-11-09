import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Manages global memory safety, especially for low-RAM iOS devices.
class MemorySafetyManager with WidgetsBindingObserver {
  static final MemorySafetyManager _instance = MemorySafetyManager._internal();
  factory MemorySafetyManager() => _instance;
  MemorySafetyManager._internal();

  final _lowMemoryStreamController = StreamController<bool>.broadcast();
  Stream<bool> get lowMemoryStream => _lowMemoryStreamController.stream;

  bool _isUnderPressure = false;
  bool get isUnderPressure => _isUnderPressure;

  // Track active readers to avoid evicting live images while user is reading
  int _activeReaderCount = 0;
  int get activeReaderCount => _activeReaderCount;

  // Default limits: 80MB / 40 images (conservative for 2GB RAM devices)
  final int _defaultMaxBytes = 80 * 1024 * 1024;
  final int _defaultMaxCount = 40;

  /// Initializes the manager and sets platform-specific image cache limits.
  void init() {
    WidgetsBinding.instance.addObserver(this);
    _applyInitialLimits();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lowMemoryStreamController.close();
  }

  void _applyInitialLimits() {
    if (Platform.isIOS) {
      // Apply baseline limit (prevents OOM on iPhone 6s Plus)
      PaintingBinding.instance.imageCache.maximumSizeBytes = _defaultMaxBytes;
      PaintingBinding.instance.imageCache.maximumSize = _defaultMaxCount;
      debugPrint('MemorySafetyManager: Baseline limits applied (${_defaultMaxBytes ~/ 1048576}MB / $_defaultMaxCount imgs)');
    }
  }

  @override
  void didHaveMemoryPressure() {
    debugPrint('MemorySafetyManager: SYSTEM MEMORY PRESSURE DETECTED');
    _isUnderPressure = true;
    
    // Perform aggressive clear immediately
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint('MemorySafetyManager: Aggressively cleared all image caches');

    // 2. Notify listeners (Reader) to shrink their windows
    _lowMemoryStreamController.add(true);
    
    // Reset pressure flag after a delay
    Timer(const Duration(minutes: 5), () {
      _isUnderPressure = false;
      _lowMemoryStreamController.add(false);
    });
  }

  /// Call when a reader screen becomes visible.
  void registerReaderVisible() {
    _activeReaderCount++;
    if (_activeReaderCount == 1) {
      // When reader opens, slightly increase cache allowance but STAY CONSERVATIVE.
      PaintingBinding.instance.imageCache.maximumSizeBytes = (_defaultMaxBytes * 1.5).toInt();
      PaintingBinding.instance.imageCache.maximumSize = (_defaultMaxCount * 1.5).toInt();
      debugPrint('MemorySafetyManager: Reader registered — slightly raised limits');
    }
  }

  /// Call when a reader screen is disposed/hidden.
  void unregisterReaderVisible() {
    if (_activeReaderCount > 0) _activeReaderCount--;
    if (_activeReaderCount == 0) {
      // Restore baseline
      PaintingBinding.instance.imageCache.maximumSizeBytes = _defaultMaxBytes;
      PaintingBinding.instance.imageCache.maximumSize = _defaultMaxCount;
      debugPrint('MemorySafetyManager: Reader unregistered — restored baseline results');

      // Always clear cache when closing a reader to free memory for the rest of the app
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  }
}
