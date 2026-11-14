import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../models/monument.dart';
import '../constants/app_constants.dart';
import 'api_service.dart';

/// Where a GLB for model_viewer_plus came from.
class ResolvedModel {
  const ResolvedModel({required this.src, required this.origin});

  /// Value to pass to ModelViewer.src (asset path or file:// URI).
  final String src;

  /// 'bundled' or 'backend'
  final String origin;
}

/// Finds a GLB for a monument: first a bundled asset, otherwise download it from the
/// backend into the app's cache folder. Throws [ApiException] with a helpful message
/// when neither is available.
class ModelSourceResolver {
  ModelSourceResolver({AssetBundle? bundle, Directory? cacheDir})
      : _bundle = bundle ?? rootBundle,
        _cacheDir = cacheDir;

  final AssetBundle _bundle;
  final Directory? _cacheDir;

  Future<ResolvedModel> resolve(Monument monument, HeritageApi api) async {
    final String assetPath = AppConfig.bundledModelAsset(monument.id);
    try {
      await _bundle.load(assetPath);
      return ResolvedModel(src: assetPath, origin: 'bundled');
    } catch (_) {
      // not bundled - fall through to the backend
    }

    final Uint8List bytes = await api.downloadModel(monument.id);
    final Directory dir = _cacheDir ?? Directory.systemTemp;
    final File file = File('${dir.path}/${monument.id}.glb');
    try {
      await file.writeAsBytes(bytes, flush: true);
    } on FileSystemException {
      throw const ApiException(
        ApiErrorKind.client,
        'The 3D model was downloaded but could not be saved on this phone.',
      );
    }
    return ResolvedModel(src: 'file://${file.path}', origin: 'backend');
  }
}
