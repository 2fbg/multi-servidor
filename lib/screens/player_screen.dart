import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/channel.dart';
import '../services/storage.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _startPlayer();
  }

  Future<void> _startPlayer() async {
    try {
      final url = widget.channel.streamUrl;

      if (url == null || url.isEmpty) {
        setState(() {
          _error = 'Link inválido.';
          _loading = false;
        });
        return;
      }

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 MultiServidor',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await controller.initialize().timeout(const Duration(seconds: 35));

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        playbackSpeeds: const [0.5, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0],
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white54,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Não foi possível reproduzir.\n\n$errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        },
      );

      if (!mounted) return;

      setState(() {
        _video = controller;
        _chewie = chewie;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Falha ao abrir o vídeo.\n\nDetalhe técnico:\n$e\n\nTente outro canal, outro servidor ou playlist em formato M3U8.';
        _loading = false;
      });
    }
  }

  Future<void> _saveProgress() async {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;

    await AppStorage.saveWatch(
      widget.channel,
      video.value.position,
      video.value.duration,
    );
  }

  @override
  void dispose() {
    _saveProgress();

    _chewie?.dispose();
    _video?.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(widget.channel.title)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red),
              SizedBox(height: 16),
              Text('Abrindo player...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(widget.channel.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.channel.title)),
      body: Center(
        child: AspectRatio(
          aspectRatio: _video!.value.aspectRatio <= 0 ? 16 / 9 : _video!.value.aspectRatio,
          child: Chewie(controller: _chewie!),
        ),
      ),
    );
  }
}
