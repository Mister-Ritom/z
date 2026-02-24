import 'package:z/models/song_model.dart';
import 'package:z/supabase/database.dart';

class SongService {
  static Future<List<SongModel>> getAllSongs() async {
    try {
      final List<dynamic> data = await Database.client.from('songs').select();
      return data.map((d) => SongModel.fromMap(d['id'], d)).toList();
    } catch (e) {
      return [];
    }
  }
}
