import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:listen_sharing_intent/listen_sharing_intent.dart';
import 'package:z/services/sharing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharingService', () {
    late SharingService sharingService;
    late Directory tempDir;

    setUp(() async {
      sharingService = SharingService();
      tempDir = await Directory.systemTemp.createTemp('sharing_service_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('convertToXFiles returns only existing files', () async {
      final existingFile = File('${tempDir.path}/existing.jpg');
      await existingFile.writeAsString('content');
      final missingPath = '${tempDir.path}/missing.jpg';

      final sharedFiles = [
        SharedMediaFile(path: existingFile.path, type: SharedMediaType.image),
        SharedMediaFile(path: missingPath, type: SharedMediaType.image),
      ];

      final xFiles = await sharingService.convertToXFiles(sharedFiles);

      expect(xFiles.length, 1);
      expect(xFiles.first.path, existingFile.path);
      expect(xFiles.first, isA<XFile>());
    });
  });
}
