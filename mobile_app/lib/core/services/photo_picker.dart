import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

class PickedPhoto {
  const PickedPhoto(this.bytes, this.name);

  final Uint8List bytes;
  final String name;
}

class PhotoPickException implements Exception {
  const PhotoPickException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Wrapper around image_picker. Returns null when the user cancels.
abstract class PhotoPicker {
  Future<PickedPhoto?> pick(PhotoSource source);
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return null; // cancelled
      final Uint8List bytes = await file.readAsBytes();
      return PickedPhoto(bytes, file.name.isEmpty ? 'photo.jpg' : file.name);
    } on PlatformException catch (e) {
      throw PhotoPickException(
        source == PhotoSource.camera
            ? 'The camera could not be opened (${e.code}). Check camera permission or use the gallery.'
            : 'The gallery could not be opened (${e.code}).',
      );
    }
  }
}
