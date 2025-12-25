abstract class CreationPage {
  Future<CreationResult?> onNext();
}

enum CreationResult { success, stay }
