part of 'main.dart';

class MiniPreviewPlayer extends StatefulWidget {
  final StreamItem? item;
  final VoidCallback? onOpenFull;

  const MiniPreviewPlayer({
    super.key,
    required this.item,
    this.onOpenFull,
  });

  @override
  State<MiniPreviewPlayer> createState() => _MiniPreviewPlayerState();
}

class _MiniPreviewPlayerState extends State<MiniPreviewPlayer> {
  VideoPlayerController? controller;
  String? error;
  bool loading = false;
  String? currentUrl;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant MiniPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item?.url != widget.item?.url) {
      load();
    }
  }

  Future<void> load() async {
    await controller?.dispose();
    controller = null;
    error = null;
    currentUrl = widget.item?.url;

    if (widget.item == null || widget.item!.url.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(widget.item!.url),
        httpHeaders: iptvHeaders(),
      );

      await c.initialize().timeout(const Duration(seconds: 20));
      await c.setVolume(0);
      await c.play();

      if (!mounted || currentUrl != widget.item?.url) {
        await c.dispose();
        return;
      }

      controller = c;
    } catch (e) {
      error = e.toString();
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    if (item == null) {
      return const Center(
        child: Text(
          'Selecione um canal para prévia',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 175,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          clipBehavior: Clip.antiAlias,
          child: loading
              ? const Center(child: CircularProgressIndicator(color: kRed))
              : error != null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Prévia indisponível.\nToque em assistir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  : controller != null && controller!.value.isInitialized
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller!.value.size.width,
                            height: controller!.value.size.height,
                            child: VideoPlayer(controller!),
                          ),
                        )
                      : const Center(child: Icon(Icons.live_tv, size: 80)),
        ),
        const SizedBox(height: 14),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          item.group,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kRed),
          onPressed: widget.onOpenFull,
          icon: const Icon(Icons.open_in_full),
          label: const Text('Assistir'),
        ),
      ],
    );
  }
}
