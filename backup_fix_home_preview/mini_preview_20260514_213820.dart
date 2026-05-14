part of 'main.dart';

class MiniPreviewPlayer extends StatefulWidget {
  final StreamItem item;
  final VoidCallback onFullscreen;

  const MiniPreviewPlayer({
    super.key,
    required this.item,
    required this.onFullscreen,
  });

  @override
  State<MiniPreviewPlayer> createState() => _MiniPreviewPlayerState();
}

class _MiniPreviewPlayerState extends State<MiniPreviewPlayer> {
  VideoPlayerController? controller;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void didUpdateWidget(covariant MiniPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.url != widget.item.url) {
      restart();
    }
  }

  Future<void> restart() async {
    await controller?.dispose();
    controller = null;
    error = null;
    loading = true;
    if (mounted) setState(() {});
    await start();
  }

  Future<void> start() async {
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(widget.item.url),
        httpHeaders: iptvHeaders(),
      );

      controller = c;
      await c.initialize().timeout(const Duration(seconds: 25));
      await c.setVolume(0);
      await c.play();

      if (mounted) {
        setState(() => loading = false);
      }
    } on TimeoutException {
      error = 'Prévia demorou demais.';
      if (mounted) setState(() => loading = false);
    } catch (e) {
      error = 'Sem prévia';
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onFullscreen,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: kRed))
            : error != null ||
                    controller == null ||
                    !controller!.value.isInitialized
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.item.logo.isNotEmpty)
                        Image.network(
                          widget.item.logo,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return const Icon(Icons.live_tv, size: 72);
                          },
                        )
                      else
                        const Center(child: Icon(Icons.live_tv, size: 72)),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            error ?? 'Sem prévia',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller!.value.size.width,
                          height: controller!.value.size.height,
                          child: VideoPlayer(controller!),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '2 toques: tela cheia',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
