import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../api/api_client.dart';

class ImageUploadService {
  const ImageUploadService();

  Dio get _api => ApiClient.instance.dio;

  Future<List<String>> uploadImages(
    List<String> paths, {
    Options? options,
    Future<void> Function(List<String> paths)? onProgress,
  }) async {
    final urls = List<String>.from(paths);
    for (var index = 0; index < urls.length; index++) {
      final path = urls[index];
      if (_isRemoteUrl(path)) continue;
      urls[index] = await uploadImage(File(path), options: options);
      // Preserve successful uploads even when a later image fails.
      await onProgress?.call(List<String>.unmodifiable(urls));
    }
    return urls;
  }

  Future<String> uploadImage(File file, {Options? options}) async {
    final ext = _extensionFor(file.path);
    final contentType = _contentTypeFor(ext);

    final presignResp = await _api.post<Map<String, dynamic>>(
      '/api/v1/uploads/presign',
      options: options,
      data: {'ext': ext, 'content_type': contentType},
    );
    final presign = presignResp.data ?? const <String, dynamic>{};
    final endpoint = presign['endpoint']?.toString();
    final url = presign['url']?.toString();
    final fields = presign['fields'];
    if (endpoint == null ||
        Uri.tryParse(endpoint)?.scheme != 'https' ||
        url == null ||
        Uri.tryParse(url)?.scheme != 'https' ||
        fields is! Map ||
        fields['x-oss-signature-version'] != 'OSS4-HMAC-SHA256') {
      throw const ImageUploadException('图片上传授权无效');
    }

    final form = FormData();
    form.fields.addAll(
      fields.entries.map(
        (entry) => MapEntry(entry.key.toString(), entry.value.toString()),
      ),
    );
    form.files.add(
      MapEntry(
        'file',
        await MultipartFile.fromFile(
          file.path,
          filename: p.basename(file.path),
          contentType: DioMediaType.parse(contentType),
        ),
      ),
    );

    final storage = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    try {
      await storage.post<void>(endpoint, data: form);
    } finally {
      storage.close();
    }
    return url;
  }

  bool _isRemoteUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  String _extensionFor(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' || 'png' || 'webp' || 'heic' || 'heif' || 'gif' => ext,
      _ => 'jpg',
    };
  }

  String _contentTypeFor(String ext) {
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }
}

class ImageUploadException implements Exception {
  const ImageUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
