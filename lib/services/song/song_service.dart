import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/models/song_model.dart';

class SongService {
  static final _db = FirebaseFirestore.instance.collection('songs');

  static Future<List<SongModel>> getAllSongs() async {
    final snapshot = await _db.get();
    return snapshot.docs
        .map((doc) => SongModel.fromMap(doc.id, doc.data()))
        .toList();
  }
}
