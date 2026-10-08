import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CompressedImageResult {
  const CompressedImageResult({
    required this.file,
    required this.sizeInBytes,
    required this.mimeType,
  });

  final File file;
  final int sizeInBytes;
  final String mimeType;

  double get sizeInKb => sizeInBytes / 1024;
}

class ImageCompressor {
  ImageCompressor._();

  static const int maxLongEdge = 1440;
  static const int maxSizeBytes = 400 * 1024; // 400 KB cap

  /// Compresses [inputFile] on-device:
  /// - Resizes long edge to max 1440px
  /// - Strips EXIF metadata
  /// - Converts to WebP (or JPEG fallback) at ~80% quality
  /// - Ensures final size is under 400 KB
  static Future<CompressedImageResult> compressForUpload(File inputFile) async {
    final tempDir = await getTemporaryDirectory();
    final uniqueName = 'compressed_${DateTime.now().millisecondsSinceEpoch}';
    final targetPath = p.join(tempDir.path, '$uniqueName.webp');

    // First pass: Quality 80
    var resultXFile = await FlutterImageCompress.compressAndGetFile(
      inputFile.absolute.path,
      targetPath,
      minWidth: 1080,
      minHeight: maxLongEdge,
      quality: 80,
      format: CompressFormat.webp,
    );

    // Fallback to JPEG if WebP encoding failed
    if (resultXFile == null) {
      final jpegPath = p.join(tempDir.path, '$uniqueName.jpg');
      resultXFile = await FlutterImageCompress.compressAndGetFile(
        inputFile.absolute.path,
        jpegPath,
        minWidth: 1080,
        minHeight: maxLongEdge,
        quality: 80,
      );
    }

    var resultFile = File(resultXFile?.path ?? inputFile.path);
    var size = await resultFile.length();

    // If still over 400 KB, perform a second aggressive compression pass
    if (size > maxSizeBytes) {
      final aggressivePath = p.join(tempDir.path, '${uniqueName}_opt.webp');
      final secondPass = await FlutterImageCompress.compressAndGetFile(
        resultFile.path,
        aggressivePath,
        minWidth: 900,
        minHeight: 1200,
        quality: 65,
        format: CompressFormat.webp,
      );

      if (secondPass != null) {
        resultFile = File(secondPass.path);
        size = await resultFile.length();
      }
    }

    final isWebp = resultFile.path.endsWith('.webp');
    final mime = isWebp ? 'image/webp' : 'image/jpeg';

    return CompressedImageResult(
      file: resultFile,
      sizeInBytes: size,
      mimeType: mime,
    );
  }
}
