import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:z/screens/creation/abstract_page.dart';
import 'package:z/widgets/common/app_image.dart';
import 'package:z/widgets/media/camera_view.dart';

class StoryCreation extends ConsumerStatefulWidget {
  const StoryCreation({super.key});

  @override
  ConsumerState<StoryCreation> createState() => StoryCreationState();
}

class StoryCreationState extends ConsumerState<StoryCreation>
    implements CreationPage {
  final mediaProvider = StateProvider<XFile?>((ref) => null);
  final showCaptionProvider = StateProvider<bool>((ref) => true);
  final textOnlyProvider = StateProvider<bool>((ref) => false);

  Future<XFile?> _pickMedia() async {
    final List<XFile>? files = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => const CameraView(
              limit: 1,
              require: false,
              title: "Story Camera",
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    return (files != null && files.isNotEmpty) ? files.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(mediaProvider);
    final showCaption = ref.watch(showCaptionProvider);
    final textOnly = ref.watch(textOnlyProvider);

    return SingleChildScrollView(
      child: CoolColumn(
        margin: const EdgeInsets.all(12),
        divider: const SizedBox(height: 12),
        children: [
          textOnly
              ? SizedBox.shrink()
              : GestureDetector(
                onTap: () async {
                  final newMedia = await _pickMedia();
                  if (newMedia != null && mounted) {
                    ref.read(mediaProvider.notifier).state = newMedia;
                  }
                },
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.orange,
                              Colors.deepPurple,
                              Colors.blueAccent,
                            ],
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child:
                            (!textOnly && media != null)
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AppImage.xFile(
                                    media,
                                    fit: BoxFit.cover,
                                  ),
                                )
                                : SizedBox(
                                  width: double.infinity,
                                  height: MediaQuery.heightOf(context),
                                  child: Center(
                                    child: Text(
                                      "No media selected",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                      ),

                      Positioned(
                        right: 12,
                        top: 24,
                        child: CoolColumn(
                          divider: const SizedBox(height: 6),
                          children: [
                            CoolIconButton(
                              icon: LucideIcons.pen,
                              onPressed: () {
                                ref.read(showCaptionProvider.notifier).state =
                                    !showCaption;
                              },
                            ),
                            CoolIconButton(
                              icon: LucideIcons.caseSensitive,
                              onPressed: () {
                                ref.read(textOnlyProvider.notifier).state =
                                    !textOnly;
                                if (!textOnly) {
                                  ref.read(mediaProvider.notifier).state = null;
                                }
                              },
                            ),
                            CoolIconButton(
                              icon: LucideIcons.sticker,
                              onPressed: () {},
                            ),
                            CoolIconButton(
                              icon: LucideIcons.brush,
                              onPressed: () {},
                            ),
                            CoolIconButton(
                              icon: LucideIcons.music,
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (showCaption)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: CoolTextField(
                hintText: "Add Caption...",
                maxLines: textOnly ? 8 : 3,
              ),
            ),
          SizedBox(height: 128),
        ],
      ),
    );
  }

  @override
  Future<CreationResult?> onNext() async {
    return CreationResult.success;
  }
}
