import 'package:flutter/material.dart';
import '../../services/api/api_client.dart';

/// Refresh short-lived image authorization on display. Never fall back to public URLs.
class PrivateJournalImage extends StatefulWidget {
  const PrivateJournalImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.errorBuilder,
  });
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final ImageErrorWidgetBuilder? errorBuilder;
  @override
  State<PrivateJournalImage> createState() => _PrivateJournalImageState();
}

class _PrivateJournalImageState extends State<PrivateJournalImage> {
  late Future<String> _url;
  @override
  void initState() {
    super.initState();
    _url = _resolve();
  }

  @override
  void didUpdateWidget(PrivateJournalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _url = _resolve();
  }

  Future<String> _resolve() async {
    final response = await ApiClient.instance.dio.post<Map<String, dynamic>>(
      '/api/v1/uploads/read-url',
      data: {'url': widget.url},
    );
    return response.data!['url'] as String;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _url,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return widget.errorBuilder?.call(
              context,
              snapshot.error!,
              StackTrace.current,
            ) ??
            const Icon(Icons.broken_image_outlined);
      }
      if (!snapshot.hasData) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 1),
            ),
          ),
        );
      }
      return Image.network(
        snapshot.data!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        cacheWidth: widget.cacheWidth,
        errorBuilder: widget.errorBuilder,
      );
    },
  );
}
