import 'package:cloud_firestore/cloud_firestore.dart';

enum BlockType {
  post, // Block specific post/short
  userContent, // Block user for zaps/shorts (affects recommendations)
  userMessaging, // Block user for messaging only (doesn't affect recommendations)
}

class BlockModel {
  final String id;
  final String blockerId;
  final BlockType blockType;
  final String? blockedPostId; // For post blocks
  final String? blockedUserId; // For user blocks
  final DateTime createdAt;

  BlockModel({
    required this.id,
    required this.blockerId,
    required this.blockType,
    this.blockedPostId,
    this.blockedUserId,
    required this.createdAt,
  });

  factory BlockModel.fromMap(Map<String, dynamic> map) {
    return BlockModel(
      id: map['id'] ?? '',
      blockerId: map['blockerId'] ?? '',
      blockType: _blockTypeFromString(map['blockType'] ?? 'post'),
      blockedPostId: map['blockedPostId'],
      blockedUserId: map['blockedUserId'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'blockerId': blockerId,
      'blockType': _blockTypeToString(blockType),
      'blockedPostId': blockedPostId,
      'blockedUserId': blockedUserId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static BlockType _blockTypeFromString(String str) {
    switch (str) {
      case 'userContent':
        return BlockType.userContent;
      case 'userMessaging':
        return BlockType.userMessaging;
      case 'post':
        return BlockType.post;
      default:
        return BlockType.post;
    }
  }

  static String _blockTypeToString(BlockType type) {
    switch (type) {
      case BlockType.userContent:
        return 'userContent';
      case BlockType.userMessaging:
        return 'userMessaging';
      case BlockType.post:
        return 'post';
    }
  }
}

