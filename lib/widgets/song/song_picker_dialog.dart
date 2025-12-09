import 'package:flutter/material.dart';
import 'package:z/models/song_model.dart';
import 'package:z/services/song/song_service.dart';

class SongPickerDialog extends StatefulWidget {
  const SongPickerDialog({super.key});

  @override
  State<SongPickerDialog> createState() => _SongPickerDialogState();
}

class _SongPickerDialogState extends State<SongPickerDialog> {
  late Future<List<SongModel>> _songsFuture;
  SongModel? _selected;

  @override
  void initState() {
    super.initState();
    _songsFuture = SongService.getAllSongs();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Pick a Song",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<SongModel>>(
                future: _songsFuture,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final songs = snap.data!;

                  if (songs.isEmpty) {
                    return const Center(child: Text("No songs available"));
                  }

                  return ListView.builder(
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      final selected = _selected?.id == song.id;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(song.coverUrl),
                        ),
                        title: Text(song.title),
                        subtitle: Text(song.artist),
                        trailing:
                            selected
                                ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                                : const Icon(Icons.radio_button_unchecked),
                        onTap: () {
                          setState(() {
                            _selected = song;
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed:
                  _selected == null
                      ? null
                      : () => Navigator.pop(context, _selected),
              child: const Text("Select"),
            ),
          ],
        ),
      ),
    );
  }
}
