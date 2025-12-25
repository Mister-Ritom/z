import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/screens/creation/abstract_page.dart';
import 'package:z/screens/main_navigation.dart';
import 'package:z/services/analytics/firebase_analytics_service.dart';
import 'package:z/utils/constants.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/utils/logger.dart';
import 'package:z/widgets/common/app_image.dart';
import 'package:z/widgets/cool_widgets/cool_widgets.dart';
import 'package:z/widgets/media/camera_view.dart';
import 'package:z/widgets/media/media_carousel.dart';
import 'package:z/widgets/media/video_player_widget.dart';

extension PrivacyIcon on Privacy {
  IconData toIcon() {
    switch (this) {
      case Privacy.eveyrone:
        return LucideIcons.globe;
      case Privacy.followers:
        return LucideIcons.users;
      case Privacy.unlisted:
        return LucideIcons.lock;
    }
  }
}

class PostCreation extends ConsumerStatefulWidget {
  const PostCreation({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return PostCreationState();
  }
}

class PostCreationState extends ConsumerState<PostCreation>
    implements CreationPage {
  final mediaStateProvider = StateProvider((ref) => <XFile>[]);
  final previewTypeProvider = StateProvider((ref) => 0);
  final privacyTypeProvider = StateProvider((ref) => Privacy.eveyrone);
  final captionController = TextEditingController();
  Privacy get privacyType => ref.watch(privacyTypeProvider);
  set privacyType(Privacy privacy) =>
      ref.read(privacyTypeProvider.notifier).state = privacy;
  int get previewType => ref.watch(previewTypeProvider);
  set previewType(int type) =>
      ref.read(previewTypeProvider.notifier).state = type;
  List<XFile> get media => ref.watch(mediaStateProvider);
  set media(List<XFile> files) {
    ref.read(mediaStateProvider.notifier).state = files;
  }

  Future<void> initMedia() async {
    if (media.isEmpty) {
      final List<XFile>? files = await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => const CameraView(
                limit: 10,
                title: "Post Camera",
                require: false,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      if (files != null && files.isNotEmpty) {
        media = files;
      }
    }
  }

  Widget mediaWidget(XFile media) {
    Widget widget;
    if (Helpers.isVideoPath(media.path)) {
      widget = SizedBox(
        width: 200,
        child: VideoPlayerWidget(isFile: true, url: media.path),
      );
    } else {
      widget = Container(
        width: 300,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: AppImage.xFile(media, fit: BoxFit.cover),
      );
    }
    return widget;
  }

  Widget shuffleWidget() {
    if (media.isEmpty) {
      return Center(
        child: InkWell(
          onTap: () => initMedia(),
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange, Colors.deepPurple, Colors.blueAccent],
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(32)),
            ),
            child: CoolColumn(
              mainAxisAlignment: MainAxisAlignment.center,
              divider: SizedBox(height: 8),
              children: [
                Icon(LucideIcons.camera, color: Colors.white),
                Text(
                  "No media selected",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 48),
      child: CoolShuffledStack(
        items: media.map(mediaWidget).toList(),
        maxSize: Size(MediaQuery.widthOf(context), 300),
        offsetStep: Offset(24, 12),
        onDragLeft: (index) {
          if (media.length == 1) {
            media = [];
            return;
          }
          final newMedia = <XFile>[];
          newMedia.addAll(media);
          newMedia.removeAt(index);
          media = newMedia;
        },
      ),
    );
  }

  Widget carousalWidget() {
    if (media.isEmpty) {
      return shuffleWidget(); //If media is empty just use the container
    }
    return SizedBox(
      width: MediaQuery.widthOf(context),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        child: MediaCarousel(
          mediaUrls: media.map((m) => m.path).toList(),
          maxHeight: 300,
        ),
      ),
    );
  }

  Widget previewToggleIcon({
    required bool active,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  active
                      ? Colors.black.withOpacityAlpha(0.55)
                      : Colors.black.withOpacityAlpha(0.30),
              borderRadius: BorderRadius.circular(12),
              border:
                  active
                      ? Border.all(color: Colors.white.withOpacityAlpha(0.35))
                      : null,
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: active ? 1.1 : 1.0,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget previewAnimatedSwitcher({
    required int previewType,
    required Widget shuffle,
    required Widget carousel,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(previewType),
        child: previewType == 0 ? shuffle : carousel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: CoolColumn(
        divider: SizedBox(height: 8),
        margin: EdgeInsets.all(8),
        children: [
          SizedBox(
            height: 300,
            width: MediaQuery.widthOf(context),
            child: Stack(
              children: [
                previewAnimatedSwitcher(
                  previewType: previewType,
                  shuffle: shuffleWidget(),
                  carousel: carousalWidget(),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      previewToggleIcon(
                        active: previewType == 0,
                        icon: LucideIcons.layers,
                        onTap: () => previewType = 0,
                      ),
                      const SizedBox(height: 8),
                      previewToggleIcon(
                        active: previewType == 1,
                        icon: LucideIcons.images,
                        onTap: () => previewType = 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          CoolTextField(
            labelText: "Caption",
            maxLines: 3,
            controller: captionController,
          ),
          CoolSection(
            title: "Quick Actions",
            initialExpanded: true,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CoolRow(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CoolIconButton(icon: LucideIcons.music),
                  CoolIconButton(icon: LucideIcons.smilePlus),
                  CoolIconButton(icon: LucideIcons.atSign),
                  CoolIconButton(icon: LucideIcons.hash),
                  CoolIconButton(icon: LucideIcons.clock12),
                ],
              ),
            ),
          ),
          CoolSection(
            title: "Privacy",
            child: ListTile(
              title: Text("Share to"),
              subtitle: Text("Share to specific groups"),
              subtitleTextStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              trailing: CoolPopupMenu(
                items:
                    Privacy.values
                        .map(
                          (e) => CoolMenuItem(
                            label: e.toString(),
                            icon: e.toIcon(),
                            onTap: () => privacyType = e,
                          ),
                        )
                        .toList(),
                child: Text(privacyType.toString()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<CreationResult?> onNext() async {
    final String text = captionController.text.trim();
    if (media.isEmpty && text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Cannot upload empty post")));
      return CreationResult.stay;
    }
    final currentUserId = ref.read(currentUserProvider).valueOrNull?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("User not authenticated")));
      return CreationResult.stay;
    }
    final id =
        FirebaseFirestore.instance
            .collection(AppConstants.zapsCollection)
            .doc()
            .id;
    final zapService = ref.read(zapServiceProvider(false));
    if (media.isNotEmpty) {
      final uploadService = ref.read(uploadNotifierProvider.notifier);
      uploadService.uploadFiles(
        files: media,
        type: UploadType.zap,
        referenceId: id,
        onComplete: (urls) async {
          await zapService.createZap(
            zapId: id,
            userId: currentUserId,
            text: text,
            mediaUrls: urls,
          );
          await FirebaseAnalyticsService.logPostCreated(
            contentType: 'media',
            isShort: false,
          );
        },
      );
    } else {
      await zapService.createZap(zapId: id, userId: currentUserId, text: text);
      await FirebaseAnalyticsService.logPostCreated(
        contentType: 'text',
        isShort: false,
      );
    }
    AppLogger.info(
      'ZapComposer',
      'Zap created successfully',
      data: {'zapId': id, 'isShort': false, 'hasMedia': media.isNotEmpty},
    );
    return CreationResult.success;
  }
}
