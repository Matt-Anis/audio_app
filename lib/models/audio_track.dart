class AudioTrack {
  final String id;
  final String title;
  final String category;
  final String url;
  final String? artwork;

  const AudioTrack({
    required this.id,
    required this.title,
    required this.category,
    required this.url,
    this.artwork,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'url': url,
      'artwork': artwork,
    };
  }

  factory AudioTrack.fromMap(Map<String, dynamic> map) {
    return AudioTrack(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      url: map['url'] as String,
      artwork: map['artwork'] as String?,
    );
  }
}
