import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../api/api_client.dart';

class ImageUploadService {
  const ImageUploadService();

  Dio get _api => ApiClient.instance.dio;

  Future<List<String>> uploadImages(List<String> paths) async {
    final urls = <String>[];
    for (final path in paths) {
      if (_isRemoteUrl(path)) {
        urls.add(path);
        continue;
      }
      urls.add(await uploadImage(File(path)));
    }
    return urls;
  }

  Future<String> uploadImage(File file) async {
    final ext = _extensionFor(file.path);
    final contentType = _contentTypeFor(ext);

    final presignResp = await _api.post<Map<String, dynamic>>(
      '/api/v1/uploads/presign',
      data: {'ext': ext, 'content_type': contentType},
    );
    final presign = presignResp.data ?? const <String, dynamic>{};
    final endpoint = presign['endpoint']?.toString();
    final url = presign['url']?.toString();
    if (endpoint == null || endpoint.isEmpty || url == null || url.isEmpty) {
      throw const ImageUploadException('图片上传授权无效');
    }

    final form = FormData();
    form.fields
      ..add(MapEntry('key', presign['key']?.toString() ?? ''))
      ..add(
        MapEntry('OSSAccessKeyId', presign['ossaccessid']?.toString() ?? ''),
      )
      ..add(MapEntry('policy', presign['policy']?.toString() ?? ''))
      ..add(MapEntry('signature', presign['signature']?.toString() ?? ''))
      ..add(MapEntry('Content-Type', contentType))
      ..add(const MapEntry('success_action_status', '200'));
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

    await Dio().post<void>(endpoint, data: form);
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
