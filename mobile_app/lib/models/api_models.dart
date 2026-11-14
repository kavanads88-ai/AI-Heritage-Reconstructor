/// Typed responses for /identify, /analyze-damage, /comparison and the health check.
library;

import 'dart:convert';
import 'dart:typed_data';

class Prediction {
  const Prediction({required this.id, required this.confidence});

  final String id;
  final double confidence;

  factory Prediction.fromJson(Map<String, dynamic> m) =>
      Prediction(id: m['id'] as String, confidence: (m['confidence'] as num).toDouble());
}

class IdentifyResult {
  const IdentifyResult({
    required this.monumentId,
    required this.name,
    required this.confidence,
    required this.isUnknown,
    this.top3 = const <Prediction>[],
    this.threshold,
    this.isMock = false,
    this.message,
  });

  final String? monumentId;
  final String name;
  final double? confidence; // null for mock data
  final bool isUnknown;
  final List<Prediction> top3;
  final double? threshold;
  final bool isMock;
  final String? message;

  factory IdentifyResult.fromJson(Map<String, dynamic> m) => IdentifyResult(
        monumentId: m['monument_id'] as String?,
        name: m['name'] as String,
        confidence: (m['confidence'] as num?)?.toDouble(),
        isUnknown: m['is_unknown'] as bool,
        top3: ((m['top3'] as List<dynamic>?) ?? const <dynamic>[])
            .map<Prediction>((dynamic e) => Prediction.fromJson(e as Map<String, dynamic>))
            .toList(),
        threshold: (m['threshold'] as num?)?.toDouble(),
        isMock: m['is_mock'] == true,
        message: m['message'] as String?,
      );

  /// Applies the app's own (user-adjustable) confidence threshold on top of the server's.
  bool isUnknownAt(double clientThreshold) {
    if (isMock) return false; // mock results carry no confidence; they are labelled as mock instead
    if (isUnknown || monumentId == null) return true;
    final double? c = confidence;
    return c != null && c < clientThreshold;
  }
}

class DamageRegion {
  const DamageRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.areaPercent,
  });

  final int x;
  final int y;
  final int width;
  final int height;
  final double areaPercent;

  factory DamageRegion.fromJson(Map<String, dynamic> m) => DamageRegion(
        x: (m['x'] as num).toInt(),
        y: (m['y'] as num).toInt(),
        width: (m['width'] as num).toInt(),
        height: (m['height'] as num).toInt(),
        areaPercent: (m['area_percent'] as num).toDouble(),
      );
}

class DamageResult {
  const DamageResult({
    required this.annotatedImage,
    required this.damageAreaPercent,
    required this.regionsFound,
    required this.message,
    required this.disclaimer,
    this.regions = const <DamageRegion>[],
  });

  final Uint8List annotatedImage;
  final double damageAreaPercent;
  final int regionsFound;
  final String message;
  final String disclaimer;
  final List<DamageRegion> regions;

  /// Throws FormatException (mapped to an "invalid response" error) on bad base64.
  factory DamageResult.fromJson(Map<String, dynamic> m) => DamageResult(
        annotatedImage: base64Decode(m['annotated_image_base64'] as String),
        damageAreaPercent: (m['damage_area_percent'] as num).toDouble(),
        regionsFound: (m['regions_found'] as num).toInt(),
        message: m['message'] as String,
        disclaimer: (m['disclaimer'] as String?) ??
            'Possible damage indicators from image processing — not a structural assessment.',
        regions: ((m['regions'] as List<dynamic>?) ?? const <dynamic>[])
            .map<DamageRegion>((dynamic e) => DamageRegion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ComparisonInfo {
  const ComparisonInfo({
    required this.monumentId,
    required this.presentUrl,
    required this.reconstructionUrl,
    required this.hasReconstruction,
    required this.explanation,
    required this.disclaimer,
  });

  final String monumentId;
  final String? presentUrl;
  final String? reconstructionUrl;
  final bool hasReconstruction;
  final String explanation;
  final String disclaimer;

  factory ComparisonInfo.fromJson(Map<String, dynamic> m) => ComparisonInfo(
        monumentId: m['monument_id'] as String,
        presentUrl: m['present_url'] as String?,
        reconstructionUrl: m['reconstruction_url'] as String?,
        hasReconstruction: m['has_reconstruction'] == true,
        explanation: (m['explanation'] as String?) ?? '',
        disclaimer: (m['disclaimer'] as String?) ??
            'Historically informed hypothetical visualisation — not an exact depiction of the original.',
      );
}

class HealthStatus {
  const HealthStatus({
    required this.ok,
    required this.message,
    required this.modelLoaded,
    required this.modelStatus,
    required this.mockEnabled,
  });

  final bool ok;
  final String message;
  final bool modelLoaded;
  final String modelStatus;
  final bool mockEnabled;

  factory HealthStatus.fromJson(Map<String, dynamic> m) => HealthStatus(
        ok: m['status'] == 'ok',
        message: (m['message'] as String?) ?? '',
        modelLoaded: m['model_loaded'] == true,
        modelStatus: (m['model_status'] as String?) ?? 'unknown',
        mockEnabled: m['mock_identify_enabled'] == true,
      );
}
