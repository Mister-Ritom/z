class SongModel {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final String audioUrl;
  final int durationMs;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.audioUrl,
    required this.durationMs,
  });

  factory SongModel.fromMap(String id, Map<String, dynamic> map) {
    return SongModel(
      id: id,
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      coverUrl: map['coverUrl'] ?? '',
      audioUrl: map['audioUrl'] ?? '',
      durationMs: map['durationMs'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'coverUrl': coverUrl,
      'audioUrl': audioUrl,
      'durationMs': durationMs,
    };
  }
}
