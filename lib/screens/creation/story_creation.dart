import 'dart:ui';
import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:z/screens/creation/abstract_page.dart';
import 'package:z/widgets/common/app_image.dart';
import 'package:z/widgets/media/camera_view.dart';

class StoryCreation extends ConsumerStatefulWidget {
  final List<XFile>? initialMedia;
  final String? initialText;
  const StoryCreation({super.key, this.initialMedia, this.initialText});

  @override
  ConsumerState<StoryCreation> createState() => StoryCreationState();
}

class StoryCreationState extends ConsumerState<StoryCreation>
    implements CreationPage {
  final mediaProvider = StateProvider<XFile?>((ref) => null);
  final showCaptionProvider = StateProvider<bool>((ref) => true);
  final textOnlyProvider = StateProvider<bool>((ref) => false);
  late final TextEditingController captionController;

  @override
  void initState() {
    super.initState();
    captionController = TextEditingController(text: widget.initialText);
    if (widget.initialMedia != null && widget.initialMedia!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(mediaProvider.notifier).state = widget.initialMedia!.first;
      });
    }
  }

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
                        right: 16,
                        top: 32,
                        child: CoolColumn(
                          divider: const SizedBox(height: 12),
                          children: [
                            _PremiumIconButton(
                              icon: LucideIcons.pen,
                              onPressed: () {
                                ref.read(showCaptionProvider.notifier).state =
                                    !showCaption;
                              },
                            ),
                            _PremiumIconButton(
                              icon: LucideIcons.caseSensitive,
                              onPressed: () {
                                ref.read(textOnlyProvider.notifier).state =
                                    !textOnly;
                                if (!textOnly) {
                                  ref.read(mediaProvider.notifier).state = null;
                                }
                              },
                            ),
                            _PremiumIconButton(
                              icon: LucideIcons.sticker,
                              onPressed: () {},
                            ),
                            _PremiumIconButton(
                              icon: LucideIcons.brush,
                              onPressed: () {},
                            ),
                            _PremiumIconButton(
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
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(top: 8),
              child: CoolTextField(
                hintText: "Add Caption...",
                maxLines: textOnly ? 8 : 4,
                controller: captionController,
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

class _PremiumIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _PremiumIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
