enum ChannelType {
  live,
  movie,
  series,
}

class Channel {
  final String id;
  final String title;
  final String? group;
  final String? logo;
  final String? streamUrl;
  final String? sourceName;
  final ChannelType type;

  Channel({
    required this.id,
    required this.title,
    this.group,
    this.logo,
    this.streamUrl,
    this.sourceName,
    this.type = ChannelType.live,
  });

  Channel copyWith({
    String? id,
    String? title,
    String? group,
    String? logo,
    String? streamUrl,
    String? sourceName,
    ChannelType? type,
  }) {
    return Channel(
      id: id ?? this.id,
      title: title ?? this.title,
      group: group ?? this.group,
      logo: logo ?? this.logo,
      streamUrl: streamUrl ?? this.streamUrl,
      sourceName: sourceName ?? this.sourceName,
      type: type ?? this.type,
    );
  }
}
