import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:manga_sonic/features/library/reader_page.dart';
import 'package:manga_sonic/utils/memory_safety_manager.dart';
import 'package:manga_sonic/utils/cloudflare_interceptor.dart';

/// A memory-managed page widget that only renders images when near the viewport.
class MemoryManagedPage extends StatelessWidget {
  final ReaderPage page;
  final bool isNear;

  const MemoryManagedPage({
    super.key,
    required this.page,
    required this.isNear,
  });

  @override
  Widget build(BuildContext context) {
    if (page.isSeparator) {
      return Container(
        height: 80,
        color: Colors.grey[900],
        child: Center(
          child: Text(
            page.chapterTitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: StableImageWidget(
        key: ValueKey(page.url ?? page.file?.path ?? page.chapterUrl),
        page: page,
        isNear: isNear,
      ),
    );
  }
}

/// V3 Engine: Instant zero-jump placeholders + scroll compensation.
class StableImageWidget extends StatefulWidget {
  final ReaderPage page;
  final bool isNear;
  const StableImageWidget({super.key, required this.page, required this.isNear});

  @override
  State<StableImageWidget> createState() => _StableImageWidgetState();
}

class _StableImageWidgetState extends State<StableImageWidget>
    with AutomaticKeepAliveClientMixin<StableImageWidget> {
  // Once an image becomes visible, keep it alive for at least 5 seconds
  // This prevents rapid unload/reload cycles during fast scrolling
  bool _hasBeenVisible = false;
  DateTime? _firstVisibleTime;

  @override
  void initState() {
    super.initState();
    updateKeepAlive();
    if (widget.isNear) {
      _hasBeenVisible = true;
      _firstVisibleTime = DateTime.now();
    }
  }

  @override
  void didUpdateWidget(covariant StableImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isNear && !_hasBeenVisible) {
      _hasBeenVisible = true;
      _firstVisibleTime = DateTime.now();
    }
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final aspect = widget.page.aspectRatio;

        if (aspect != null) {
          final height = width / aspect;
          // Keep image alive if it was recently visible
          // In emergency mode, we are more aggressive with unloading
          final keepAliveDuration = MemorySafetyManager().isUnderPressure
              ? const Duration(seconds: 1)
              : const Duration(seconds: 4);

          final shouldShow = widget.isNear ||
              (_hasBeenVisible &&
                  _firstVisibleTime != null &&
                  DateTime.now().difference(_firstVisibleTime!) <
                      keepAliveDuration);
          return SizedBox(
            width: width,
            height: height,
            child: shouldShow ? _buildImage() : const SizedBox.shrink(),
          );
        }

        return SizedBox(
          width: width,
          height: 800,
          child: _buildImageWithSizeDetection(width),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => widget.isNear;

  Widget _buildImage() {
    final ImageProvider provider;
    if (widget.page.file != null) {
      provider = FileImage(widget.page.file!);
    } else {
      final imageUrl = widget.page.url!;
      final referer = 'https://asurascans.com/';
      provider = CachedNetworkImageProvider(
        imageUrl,
        headers: {
          ...CloudflareInterceptor.headersForUrl(imageUrl),
          'Referer': referer,
        },
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final cacheWidth = (mediaQuery.size.width * mediaQuery.devicePixelRatio).round();

    return Image(
      image: ResizeImage(provider, width: cacheWidth),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low, // Lower quality is faster to decode/render
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        return frame != null ? child : _loadingWidget();
      },
      errorBuilder: (context, error, stackTrace) => _errorWidget(),
    );
  }

  Widget _buildImageWithSizeDetection(double availableWidth) {
    final ImageProvider provider;
    if (widget.page.file != null) {
      provider = FileImage(widget.page.file!);
    } else {
      final imageUrl = widget.page.url!;
      final referer = 'https://asurascans.com/';
      provider = CachedNetworkImageProvider(
        imageUrl,
        headers: {
          ...CloudflareInterceptor.headersForUrl(imageUrl),
          'Referer': referer,
        },
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final cacheWidth = (mediaQuery.size.width * mediaQuery.devicePixelRatio).round();

    return Image(
      image: ResizeImage(provider, width: cacheWidth),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null && widget.page.aspectRatio == null) {
          _resolveSize(provider, availableWidth, context);
        }
        return frame != null ? child : _loadingWidget();
      },
      errorBuilder: (context, error, stackTrace) => _errorWidget(),
    );
  }

  void _resolveSize(
      ImageProvider provider, double availableWidth, BuildContext context) {
    if (widget.page.aspectRatio != null) return;
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;

    final scrollPosition = Scrollable.maybeOf(context)?.position;

    listener = ImageStreamListener((info, _) {
      if (mounted) {
        final aspect = info.image.width / info.image.height;
        final heightDelta = (availableWidth / aspect) - 800.0;

        if (widget.page.aspectRatio == null) {
          setState(() {
            widget.page.aspectRatio = aspect;
          });

          if (scrollPosition != null && heightDelta.abs() > 1.0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final box = context.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                final pos = box.localToGlobal(Offset.zero);
                if (pos.dy < 0) {
                  scrollPosition.correctBy(heightDelta);
                }
              }
            });
          }
        }
      }
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  Widget _loadingWidget() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white24,
          ),
        ),
      ),
    );
  }

  Widget _errorWidget() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.white38),
      ),
    );
  }
}
