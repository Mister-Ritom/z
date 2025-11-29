import * as admin from "firebase-admin";

/**
 * Interface for a zap candidate with scoring data
 */
export interface ZapCandidate {
  zapId: string;
  userId: string;
  hashtags: string[];
  createdAt: admin.firestore.Timestamp;
  likesCount: number;
  rezapsCount: number;
  views?: number;
  score: number;
}

/**
 * User profile data for recommendations
 */
export interface UserProfile {
  tagsLiked: Record<string, number>;
  usersLiked: Record<string, number>; // Weights for creators user has liked posts from
  followedUserIds: string[];
  viewedZapIds: Set<string>;
  interactionCount: number; // Total meaningful interactions (likes, views, reposts)
}

/**
 * Scoring weights for recommendation algorithm
 */
const SCORING_WEIGHTS = {
  RELEVANCE: 0.25, // Weight for tag matching and user interests
  CREATOR_AFFINITY: 0.25, // Weight for followed creators (2-3x boost)
  POPULARITY: 0.20, // Weight for likes/views/reposts
  FRESHNESS: 0.20, // Weight for recency and new-post boost
  RANDOMNESS: 0.10, // Weight for random jitter to avoid static order
};

/**
 * Calculate tag relevance score based on user's liked tags
 */
export function calculateTagRelevance(
  zapTags: string[],
  userTagsLiked: Record<string, number>
): number {
  if (zapTags.length === 0 || Object.keys(userTagsLiked).length === 0) {
    return 0;
  }

  let totalScore = 0;
  let matchedTags = 0;

  for (const tag of zapTags) {
    const userWeight = userTagsLiked[tag] || 0;
    if (userWeight > 0) {
      // Normalize weight (log scale to prevent dominance)
      totalScore += Math.log1p(userWeight);
      matchedTags++;
    }
  }

  // Normalize by number of tags
  return matchedTags > 0 ? totalScore / Math.max(zapTags.length, 1) : 0;
}

/**
 * Calculate freshness score with new-post boost
 * Formula: max(0.2, exp(-timeSinceCreation / 2 days))
 * This gives new posts a temporary score multiplier that decays over time
 */
export function calculateFreshnessScore(
  createdAt: admin.firestore.Timestamp
): number {
  const now = Date.now();
  const zapTime = createdAt.toMillis();
  const ageInDays = (now - zapTime) / (1000 * 60 * 60 * 24);

  // New-post boost: exponential decay over 2 days
  // Minimum score of 0.2 to ensure older posts still have some visibility
  const freshnessBoost = Math.max(0.2, Math.exp(-ageInDays / 2));

  return freshnessBoost;
}

/**
 * Calculate popularity score based on engagement metrics
 * Handles zero-engagement posts by giving them a small positive base value
 */
export function calculatePopularityScore(
  likesCount: number,
  rezapsCount: number,
  views: number = 0
): number {
  // Base value for zero-engagement posts to avoid division by zero
  const baseEngagement = 0.1;
  
  // Normalize engagement metrics
  const engagementScore =
    baseEngagement +
    likesCount * 1.0 +
    rezapsCount * 1.5 +
    Math.log1p(views) * 0.5;

  // Use log scale to prevent extremely popular zaps from dominating
  return Math.log1p(engagementScore);
}

/**
 * Calculate creator affinity (2-3x boost for followed creators)
 */
export function calculateCreatorAffinity(
  zapUserId: string,
  followedUserIds: string[]
): number {
  // 2.5x multiplier for followed creators
  return followedUserIds.includes(zapUserId) ? 2.5 : 1.0;
}

/**
 * Calculate user liking score based on how often user has liked posts from this creator
 * Similar to tag relevance, but for creators
 */
export function calculateUserLikingScore(
  zapUserId: string,
  usersLiked: Record<string, number>
): number {
  if (Object.keys(usersLiked).length === 0) {
    return 0;
  }

  const userWeight = usersLiked[zapUserId] || 0;
  if (userWeight > 0) {
    // Normalize weight (log scale to prevent dominance)
    // Higher weight = more likes from this creator = higher score
    // Use log scale similar to tag relevance
    return Math.log1p(userWeight);
  }

  return 0;
}

/**
 * Generate random jitter to avoid static ordering
 * Returns a value between 0.9 and 1.1
 */
export function calculateRandomJitter(): number {
  return 0.9 + Math.random() * 0.2; // Random value between 0.9 and 1.1
}

/**
 * Calculate final recommendation score for a zap
 * Uses improved scoring formula with all components
 */
export function calculateZapScore(
  candidate: ZapCandidate,
  userProfile: UserProfile
): number {
  // Component 1: Relevance to user (tags, interests)
  const relevanceScore = calculateTagRelevance(
    candidate.hashtags,
    userProfile.tagsLiked
  );

  // Component 1.5: User liking score (how often user has liked posts from this creator)
  const userLikingScore = calculateUserLikingScore(
    candidate.userId,
    userProfile.usersLiked
  );

  // Component 2: Creator affinity (2-3x boost for followed creators)
  const affinityMultiplier = calculateCreatorAffinity(
    candidate.userId,
    userProfile.followedUserIds
  );

  // Component 3: Popularity (likes, views, reposts)
  const popularityScore = calculatePopularityScore(
    candidate.likesCount,
    candidate.rezapsCount,
    candidate.views || 0
  );

  // Component 4: Freshness (new-post boost)
  const freshnessScore = calculateFreshnessScore(candidate.createdAt);

  // Component 5: Random jitter to avoid static ordering
  const randomJitter = calculateRandomJitter();

  // Weighted combination (user liking score is part of relevance)
  const baseScore =
    (relevanceScore + userLikingScore) * SCORING_WEIGHTS.RELEVANCE +
    popularityScore * SCORING_WEIGHTS.POPULARITY +
    freshnessScore * SCORING_WEIGHTS.FRESHNESS +
    (affinityMultiplier > 1.0 ? 1.0 : 0.0) * SCORING_WEIGHTS.CREATOR_AFFINITY;

  // Apply creator affinity as multiplier (2-3x boost)
  const affinityAdjustedScore = baseScore * affinityMultiplier;

  // Add random jitter to avoid static ordering
  const finalScore = affinityAdjustedScore * (1 + (randomJitter - 1) * SCORING_WEIGHTS.RANDOMNESS);

  return finalScore;
}

/**
 * Rank zaps by their recommendation scores
 */
export function rankZaps(
  candidates: ZapCandidate[],
  userProfile: UserProfile
): ZapCandidate[] {
  // Calculate scores
  const scored = candidates.map((candidate) => ({
    ...candidate,
    score: calculateZapScore(candidate, userProfile),
  }));

  // Sort by score (descending)
  return scored.sort((a, b) => b.score - a.score);
}

