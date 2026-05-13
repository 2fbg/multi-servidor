class Channel {
  final String id;
  final String title;
  final String? group;
  final String? logo;
  final String? streamUrl;

  Channel({
    required this.id,
    required this.title,
    this.group,
    this.logo,
    this.streamUrl,
  });

  Channel copyWith({String? streamUrl}) {
    return Channel(
      id: id,
      title: title,
      group: group,
      logo: logo,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }
}