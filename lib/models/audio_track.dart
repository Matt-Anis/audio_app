class AudioTrack {
  final String id;
  final String title;
  final String category;
  final String url;

  const AudioTrack({
    required this.id,
    required this.title,
    required this.category,
    required this.url,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'url': url,
    };
  }

  factory AudioTrack.fromMap(Map<String, dynamic> map) {
    return AudioTrack(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      url: map['url'] as String,
    );
  }
}
