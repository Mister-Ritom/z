import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { ZapCandidate, UserProfile, rankZaps } from "./ranking";

const db = admin.firestore();

// Cache expiration: 6 hours in milliseconds (shorter for fresher content)
const CACHE_EXPIRATION_MS = 6 * 60 * 60 * 1000;

// Collection names
const ZAPS_COLLECTION = "zaps";
const FOLLOWING_COLLECTION = "following";
const ANALYTICS_COLLECTION = "analytics";
const USER_INTERACTIONS_COLLECTION = "user_interactions";
const CACHED_RECOMMENDATIONS_COLLECTION = "cached_recommendations";
const DAILY_CURATED_ZAPS_COLLECTION = "daily_curated_zaps";

// Limits for fetching candidates
const MAX_TRENDING_CANDIDATES = 200;
const MAX_FOLLOWED_CANDIDATES = 100;
const MAX_NEW_POSTS = 30; // New posts from last 24 hours
const MAX_OLDER_POSTS = 100; // Older posts (beyond 7 days)
const MAX_FINAL_RECOMMENDATIONS = 500; // Always generate large pool of recommendations
const MAX_CACHE_SIZE = 1000; // Upper bound for cached zap IDs (increased for endless feed)
const MIN_INTERACTIONS_FOR_PERSONALIZATION = 5; // Minimum interactions for full personalization
const PAGINATION_REFRESH_THRESHOLD = 80; // Trigger refresh when user reaches this position
const DEFAULT_PER_PAGE = 20; // Default items per page
const MIN_RANDOM_TOPUP = 5; // Minimum number of random zaps to sprinkle when near the end

type CacheMergeStrategy = "replace" | "append";
interface CacheOptions {
  mergeStrategy?: CacheMergeStrategy;
}

/**
 * Get user's tag preferences from analytics
 */
async function getUserTagPreferences(
  userId: string
): Promise<Record<string, number>> {
  try {
    const analyticsDoc = await db
      .collection(ANALYTICS_COLLECTION)
      .doc("users")
      .collection("users")
      .doc(userId)
      .get();

    const data = analyticsDoc.data();
    return (data?.tagsLiked as Record<string, number>) || {};
  } catch (error) {
    functions.logger.warn(
      `Error fetching tag preferences for ${userId}:`,
      error
    );
    return {};
  }
}

/**
 * Get user's liking preferences (weights for creators they've liked posts from)
 */
async function getUserLikingPreferences(
  userId: string
): Promise<Record<string, number>> {
  try {
    const analyticsDoc = await db
      .collection(ANALYTICS_COLLECTION)
      .doc("users")
      .collection("users")
      .doc(userId)
      .get();

    const data = analyticsDoc.data();
    return (data?.usersLiked as Record<string, number>) || {};
  } catch (error) {
    functions.logger.warn(
      `Error fetching user liking preferences for ${userId}:`,
      error
    );
    return {};
  }
}

/**
 * Get list of users that the current user follows
 */
async function getFollowedUserIds(userId: string): Promise<string[]> {
  try {
    const followingSnapshot = await db
      .collection(FOLLOWING_COLLECTION)
      .doc(userId)
      .collection("users")
      .select() // Only fetch document IDs
      .get();

    return followingSnapshot.docs.map((doc) => doc.id);
  } catch (error) {
    functions.logger.warn(
      `Error fetching followed users for ${userId}:`,
      error
    );
    return [];
  }
}

/**
 * Get zaps that the user has already viewed
 */
async function getViewedZapIds(userId: string): Promise<Set<string>> {
  try {
    const viewedSnapshot = await db
      .collection(USER_INTERACTIONS_COLLECTION)
      .doc(userId)
      .collection(ZAPS_COLLECTION)
      .where("viewed", "==", true)
      .select() // Only fetch document IDs
      .limit(1000) // Cap at 1000 to avoid excessive reads
      .get();

    return new Set(viewedSnapshot.docs.map((doc) => doc.id));
  } catch (error) {
    functions.logger.warn(`Error fetching viewed zaps for ${userId}:`, error);
    return new Set();
  }
}

/**
 * Get blocked post IDs for a user
 */
async function getBlockedPostIds(userId: string): Promise<Set<string>> {
  try {
    const blockedSnapshot = await db
      .collection("users")
      .doc(userId)
      .collection("blocked_posts")
      .select()
      .limit(1000)
      .get();

    return new Set(blockedSnapshot.docs.map((doc) => doc.id));
  } catch (error) {
    functions.logger.warn(`Error fetching blocked post IDs for ${userId}:`, error);
    return new Set();
  }
}

/**
 * Get blocked user IDs for content (affects recommendations)
 */
async function getBlockedUserIdsForContent(userId: string): Promise<Set<string>> {
  try {
    const blockedSnapshot = await db
      .collection("users")
      .doc(userId)
      .collection("blocked_users_content")
      .select()
      .limit(1000)
      .get();

    return new Set(blockedSnapshot.docs.map((doc) => doc.id));
  } catch (error) {
    functions.logger.warn(`Error fetching blocked user IDs for content for ${userId}:`, error);
    return new Set();
  }
}

/**
 * Get user IDs whose posts have been blocked (for ranking penalty)
 */
async function getUsersWithBlockedPosts(userId: string): Promise<Set<string>> {
  try {
    const blockedPostsSnapshot = await db
      .collection("users")
      .doc(userId)
      .collection("blocked_posts")
      .get();

    // Get the userIds from the blocked posts
    const userIds = new Set<string>();
    for (const doc of blockedPostsSnapshot.docs) {
      const postId = doc.id;
      try {
        // Check both zaps and shorts collections
        const zapDoc = await db.collection(ZAPS_COLLECTION).doc(postId).get();
        if (zapDoc.exists) {
          const data = zapDoc.data();
          if (data?.userId) {
            userIds.add(data.userId);
          }
        } else {
          const shortDoc = await db.collection("shorts").doc(postId).get();
          if (shortDoc.exists) {
            const data = shortDoc.data();
            if (data?.userId) {
              userIds.add(data.userId);
            }
          }
        }
      } catch (error) {
        functions.logger.warn(`Error getting userId for blocked post ${postId}:`, error);
      }
    }

    return userIds;
  } catch (error) {
    functions.logger.warn(`Error fetching users with blocked posts for ${userId}:`, error);
    return new Set();
  }
}

/**
 * Count user's meaningful interactions (likes, views, reposts)
 */
async function getUserInteractionCount(userId: string): Promise<number> {
  try {
    // Count likes
    const likedSnapshot = await db
      .collection(USER_INTERACTIONS_COLLECTION)
      .doc(userId)
      .collection(ZAPS_COLLECTION)
      .where("liked", "==", true)
      .select()
      .limit(100)
      .get();

    // Count reposts
    const repostedSnapshot = await db
      .collection(USER_INTERACTIONS_COLLECTION)
      .doc(userId)
      .collection(ZAPS_COLLECTION)
      .where("reshared", "==", true)
      .select()
      .limit(100)
      .get();

    // Count views (approximate)
    const viewedSnapshot = await db
      .collection(USER_INTERACTIONS_COLLECTION)
      .doc(userId)
      .collection(ZAPS_COLLECTION)
      .where("viewed", "==", true)
      .select()
      .limit(100)
      .get();

    // Return approximate count (capped at 100 per type for performance)
    return Math.min(
      likedSnapshot.size +
        repostedSnapshot.size +
        Math.min(viewedSnapshot.size, 50),
      300
    );
  } catch (error) {
    functions.logger.warn(`Error counting interactions for ${userId}:`, error);
    return 0;
  }
}

/**
 * Fetch trending zaps using existing indexes
 * Uses simple query: isDeleted == false, orderBy createdAt (descending)
 * This matches the existing index used by getForYouFeed
 */
async function fetchTrendingZaps(
  excludeZapIds: Set<string>,
  limit: number
): Promise<ZapCandidate[]> {
  try {
    // Use simple query that matches existing index (isDeleted + createdAt)
    const trendingSnapshot = await db
      .collection(ZAPS_COLLECTION)
      .where("isDeleted", "==", false)
      .orderBy("createdAt", "desc")
      .limit(limit * 4) // Fetch more to filter out parent zaps and excluded
      .get();

    // Filter out replies (parentZapId != null) and excluded zaps
    const validDocs = trendingSnapshot.docs.filter((doc) => {
      const data = doc.data();
      return !data.parentZapId && !excludeZapIds.has(doc.id);
    });

    if (validDocs.length === 0) return [];

    // Batch fetch analytics data
    const analyticsPromises = validDocs.map((doc) =>
      db
        .collection(ANALYTICS_COLLECTION)
        .doc(ZAPS_COLLECTION)
        .collection(ZAPS_COLLECTION)
        .doc(doc.id)
        .get()
    );

    const analyticsDocs = await Promise.all(analyticsPromises);

    const candidates: ZapCandidate[] = [];

    for (let i = 0; i < validDocs.length && candidates.length < limit; i++) {
      const doc = validDocs[i];
      const analyticsDoc = analyticsDocs[i];
      const data = doc.data();
      const analyticsData = analyticsDoc.data() || {};

      candidates.push({
        zapId: doc.id,
        userId: data.userId as string,
        hashtags: (data.hashtags as string[]) || [],
        createdAt: data.createdAt as admin.firestore.Timestamp,
        likesCount: (data.likesCount as number) || 0,
        rezapsCount: (data.rezapsCount as number) || 0,
        views: (analyticsData.views as number) || 0,
        score: 0, // Will be calculated later
      });
    }

    return candidates;
  } catch (error) {
    functions.logger.error("Error fetching trending zaps:", error);
    return [];
  }
}

/**
 * Fetch new posts from last 24 hours (for exploration boost)
 * Uses existing index: isDeleted + createdAt
 */
async function fetchNewPosts(
  excludeZapIds: Set<string>,
  limit: number
): Promise<ZapCandidate[]> {
  try {
    const oneDayAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 24 * 60 * 60 * 1000)
    );

    const newPostsSnapshot = await db
      .collection(ZAPS_COLLECTION)
      .where("isDeleted", "==", false)
      .orderBy("createdAt", "desc")
      .limit(limit * 2) // Fetch more to filter
      .get();

    // Filter for posts from last 24 hours, exclude replies and viewed
    const validDocs = newPostsSnapshot.docs.filter((doc) => {
      const data = doc.data();
      const createdAt = data.createdAt as admin.firestore.Timestamp;
      return (
        createdAt.toMillis() >= oneDayAgo.toMillis() &&
        !data.parentZapId &&
        !excludeZapIds.has(doc.id)
      );
    });

    if (validDocs.length === 0) return [];

    // Batch fetch analytics
    const analyticsPromises = validDocs.map((doc) =>
      db
        .collection(ANALYTICS_COLLECTION)
        .doc(ZAPS_COLLECTION)
        .collection(ZAPS_COLLECTION)
        .doc(doc.id)
        .get()
    );

    const analyticsDocs = await Promise.all(analyticsPromises);

    const candidates: ZapCandidate[] = [];

    for (let i = 0; i < validDocs.length && candidates.length < limit; i++) {
      const doc = validDocs[i];
      const analyticsDoc = analyticsDocs[i];
      const data = doc.data();
      const analyticsData = analyticsDoc.data() || {};

      candidates.push({
        zapId: doc.id,
        userId: data.userId as string,
        hashtags: (data.hashtags as string[]) || [],
        createdAt: data.createdAt as admin.firestore.Timestamp,
        likesCount: (data.likesCount as number) || 0,
        rezapsCount: (data.rezapsCount as number) || 0,
        views: (analyticsData.views as number) || 0,
        score: 0,
      });
    }

    return candidates;
  } catch (error) {
    functions.logger.error("Error fetching new posts:", error);
    return [];
  }
}

/**
 * Fetch older posts (beyond 7 days) with lower probability
 * Uses existing index: isDeleted + createdAt
 */
async function fetchOlderPosts(
  excludeZapIds: Set<string>,
  limit: number
): Promise<ZapCandidate[]> {
  try {
    const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    );

    // Fetch older posts, but with pagination to get variety
    // Use a random offset to avoid always getting the same old posts
    const randomOffset = Math.floor(Math.random() * 50);

    const olderSnapshot = await db
      .collection(ZAPS_COLLECTION)
      .where("isDeleted", "==", false)
      .orderBy("createdAt", "desc")
      .offset(randomOffset) // Random offset for variety
      .limit(limit * 3) // Fetch more to filter
      .get();

    // Filter for posts older than 7 days, exclude replies and viewed
    const validDocs = olderSnapshot.docs.filter((doc) => {
      const data = doc.data();
      const createdAt = data.createdAt as admin.firestore.Timestamp;
      return (
        createdAt.toMillis() < sevenDaysAgo.toMillis() &&
        !data.parentZapId &&
        !excludeZapIds.has(doc.id)
      );
    });

    if (validDocs.length === 0) return [];

    // Sample randomly to get variety (older posts have lower probability)
    const sampledDocs = validDocs
      .filter(() => Math.random() < 0.3) // 30% chance to include each older post
      .slice(0, limit);

    if (sampledDocs.length === 0) return [];

    // Batch fetch analytics
    const analyticsPromises = sampledDocs.map((doc) =>
      db
        .collection(ANALYTICS_COLLECTION)
        .doc(ZAPS_COLLECTION)
        .collection(ZAPS_COLLECTION)
        .doc(doc.id)
        .get()
    );

    const analyticsDocs = await Promise.all(analyticsPromises);

    const candidates: ZapCandidate[] = [];

    for (let i = 0; i < sampledDocs.length; i++) {
      const doc = sampledDocs[i];
      const analyticsDoc = analyticsDocs[i];
      const data = doc.data();
      const analyticsData = analyticsDoc.data() || {};

      candidates.push({
        zapId: doc.id,
        userId: data.userId as string,
        hashtags: (data.hashtags as string[]) || [],
        createdAt: data.createdAt as admin.firestore.Timestamp,
        likesCount: (data.likesCount as number) || 0,
        rezapsCount: (data.rezapsCount as number) || 0,
        views: (analyticsData.views as number) || 0,
        score: 0,
      });
    }

    return candidates;
  } catch (error) {
    functions.logger.error("Error fetching older posts:", error);
    return [];
  }
}

/**
 * Fetch zaps from followed users
 * Uses existing index: userId + isDeleted + createdAt
 */
async function fetchFollowedUserZaps(
  followedUserIds: string[],
  excludeZapIds: Set<string>,
  limit: number
): Promise<ZapCandidate[]> {
  if (followedUserIds.length === 0) return [];

  try {
    const candidates: ZapCandidate[] = [];
    const batchSize = 10; // Process in batches (whereIn supports max 10)

    for (let i = 0; i < followedUserIds.length; i += batchSize) {
      const batch = followedUserIds.slice(i, i + batchSize);

      // Use whereIn to fetch multiple users at once (matches existing index pattern)
      // Pattern: isDeleted + userId (whereIn) + createdAt
      const userZapsSnapshot = await db
        .collection(ZAPS_COLLECTION)
        .where("isDeleted", "==", false)
        .where("userId", "in", batch)
        .orderBy("createdAt", "desc")
        .limit(limit / Math.ceil(followedUserIds.length / batchSize))
        .get();

      // Filter out replies and excluded zaps
      const validUserDocs = userZapsSnapshot.docs.filter((doc) => {
        const data = doc.data();
        return !data.parentZapId && !excludeZapIds.has(doc.id);
      });

      if (validUserDocs.length === 0) continue;

      // Batch fetch analytics for this batch's zaps
      const userAnalyticsPromises = validUserDocs.map((doc) =>
        db
          .collection(ANALYTICS_COLLECTION)
          .doc(ZAPS_COLLECTION)
          .collection(ZAPS_COLLECTION)
          .doc(doc.id)
          .get()
      );

      const userAnalyticsDocs = await Promise.all(userAnalyticsPromises);

      for (
        let j = 0;
        j < validUserDocs.length && candidates.length < limit;
        j++
      ) {
        const doc = validUserDocs[j];
        const analyticsDoc = userAnalyticsDocs[j];
        const data = doc.data();
        const analyticsData = analyticsDoc.data() || {};

        candidates.push({
          zapId: doc.id,
          userId: data.userId as string,
          hashtags: (data.hashtags as string[]) || [],
          createdAt: data.createdAt as admin.firestore.Timestamp,
          likesCount: (data.likesCount as number) || 0,
          rezapsCount: (data.rezapsCount as number) || 0,
          views: (analyticsData.views as number) || 0,
          score: 0,
        });
      }

      if (candidates.length >= limit) break;
    }

    return candidates;
  } catch (error) {
    functions.logger.error("Error fetching followed user zaps:", error);
    return [];
  }
}

/**
 * Fetch similar zaps based on tags from existing recommendations
 */
async function fetchSimilarZapsByTags(
  existingZapIds: string[],
  userTags: Record<string, number>,
  excludeZapIds: Set<string>,
  limit: number
): Promise<ZapCandidate[]> {
  if (Object.keys(userTags).length === 0 || limit <= 0) return [];

  try {
    // Get top 3 most liked tags
    const topTags = Object.entries(userTags)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([tag]) => tag);

    if (topTags.length === 0) return [];

    const candidates: ZapCandidate[] = [];

    // Try to find zaps with matching tags
    for (const tag of topTags) {
      if (candidates.length >= limit) break;

      const tagSnapshot = await db
        .collection(ZAPS_COLLECTION)
        .where("isDeleted", "==", false)
        .where("parentZapId", "==", null)
        .where("hashtags", "array-contains", tag)
        .orderBy("createdAt", "desc")
        .limit(limit * 2)
        .get();

      if (tagSnapshot.empty) continue;

      const analyticsPromises = tagSnapshot.docs.map((doc) =>
        db
          .collection(ANALYTICS_COLLECTION)
          .doc(ZAPS_COLLECTION)
          .collection(ZAPS_COLLECTION)
          .doc(doc.id)
          .get()
      );

      const analyticsDocs = await Promise.all(analyticsPromises);

      for (let i = 0; i < tagSnapshot.docs.length && candidates.length < limit; i++) {
        const doc = tagSnapshot.docs[i];
        const analyticsDoc = analyticsDocs[i];
        const data = doc.data();
        const analyticsData = analyticsDoc.data() || {};

        if (excludeZapIds.has(doc.id)) continue;

        candidates.push({
          zapId: doc.id,
          userId: data.userId as string,
          hashtags: (data.hashtags as string[]) || [],
          createdAt: data.createdAt as admin.firestore.Timestamp,
          likesCount: (data.likesCount as number) || 0,
          rezapsCount: (data.rezapsCount as number) || 0,
          views: (analyticsData.views as number) || 0,
          score: 0,
        });
      }
    }

    return candidates.slice(0, limit);
  } catch (error) {
    functions.logger.error("Error fetching similar zaps by tags:", error);
    return [];
  }
}

/**
 * Get random zaps as last resort (truly random, not personalized)
 */
async function getRandomSprinkleZapIds(
  existingZapIds: string[],
  count: number
): Promise<string[]> {
  if (count <= 0) return [];

  try {
    const excludeSet = new Set(existingZapIds);
    
    // Fetch a larger pool to get variety
    const randomCandidates = await fetchTrendingZaps(
      excludeSet,
      Math.max(count * 3, 100)
    );

    // Shuffle and take random selection
    const shuffled = randomCandidates.sort(() => Math.random() - 0.5);
    return shuffled.slice(0, count).map((candidate) => candidate.zapId);
  } catch (error) {
    functions.logger.error("Error fetching random sprinkle zaps:", error);
    return [];
  }
}


/**
 * Get cached recommendations for a user
 * Returns { zapIds, isFallback, position, lastViewedZapId } or null
 */
async function getCachedRecommendations(
  userId: string
): Promise<{
  zapIds: string[];
  isFallback: boolean;
  position: number;
  lastViewedZapId: string | null;
} | null> {
  try {
    const cacheDoc = await db
      .collection(CACHED_RECOMMENDATIONS_COLLECTION)
      .doc(userId)
      .get();

    if (!cacheDoc.exists) return null;

    const data = cacheDoc.data();
    const updatedAt = data?.updatedAt as admin.firestore.Timestamp | undefined;

    if (!updatedAt) return null;

    const cacheAge = Date.now() - updatedAt.toMillis();

    // Check if cache is still valid (< 6 hours old)
    if (cacheAge < CACHE_EXPIRATION_MS) {
      return {
        zapIds: (data?.zapIds as string[]) || [],
        isFallback: (data?.isFallback as boolean) || false,
        position: (data?.lastPosition as number) || 0, // Track last position for pagination
        lastViewedZapId: (data?.lastViewedZapId as string) || null, // Last zap user viewed
      };
    }

    return null; // Cache expired
  } catch (error) {
    functions.logger.warn(`Error fetching cache for ${userId}:`, error);
    return null;
  }
}

/**
 * Save recommendations to cache
 */
async function saveRecommendationsToCache(
  userId: string,
  zapIds: string[],
  isFallback: boolean = false,
  position: number = 0,
  options: CacheOptions = {}
): Promise<void> {
  const mergeStrategy = options.mergeStrategy ?? "replace";

  try {
    let finalZapIds = zapIds.slice(0, MAX_CACHE_SIZE);

    if (mergeStrategy === "append") {
      try {
        const existingDoc = await db
          .collection(CACHED_RECOMMENDATIONS_COLLECTION)
          .doc(userId)
          .get();

        const existingZapIds =
          ((existingDoc.data()?.zapIds as string[]) || []).slice();

        // If we've already reached cache limit, start fresh with new zapIds
        if (existingZapIds.length >= MAX_CACHE_SIZE) {
          finalZapIds = zapIds.slice(0, MAX_CACHE_SIZE);
        } else {
          const seen = new Set(existingZapIds);
          const merged = [...existingZapIds];

          zapIds.forEach((id) => {
            if (!seen.has(id)) {
              merged.push(id);
              seen.add(id);
            }
          });

          if (merged.length > MAX_CACHE_SIZE) {
            const overflow = merged.length - MAX_CACHE_SIZE;
            finalZapIds = merged.slice(overflow);
          } else {
            finalZapIds = merged;
          }
        }
      } catch (error) {
        functions.logger.warn(
          `Failed to append cache for ${userId}, falling back to replace:`,
          error
        );
        finalZapIds = zapIds.slice(0, MAX_CACHE_SIZE);
      }
    }

    const safePosition = Math.min(position, finalZapIds.length);

    await db.collection(CACHED_RECOMMENDATIONS_COLLECTION).doc(userId).set({
      zapIds: finalZapIds,
      isFallback,
      lastPosition: safePosition, // Track pagination position
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    functions.logger.error(`Error saving cache for ${userId}:`, error);
  }
}

/**
 * Get paginated slice from recommendations array
 * Returns { zapIds, hasMore, nextLastZap }
 */
function getPaginatedSlice(
  allZapIds: string[],
  lastZap: string | undefined,
  perPage: number
): {
  zapIds: string[];
  hasMore: boolean;
  nextLastZap: string | null;
  position: number;
} {
  let startIndex = 0;

  // Find starting position based on lastZap
  if (lastZap) {
    const lastIndex = allZapIds.indexOf(lastZap);
    if (lastIndex >= 0) {
      startIndex = lastIndex + 1;
    }
  }

  // Get slice
  const endIndex = Math.min(startIndex + perPage, allZapIds.length);
  const zapIds = allZapIds.slice(startIndex, endIndex);
  const hasMore = endIndex < allZapIds.length;
  const nextLastZap =
    hasMore && zapIds.length > 0 ? zapIds[zapIds.length - 1] : null;
  const position = endIndex;

  return { zapIds, hasMore, nextLastZap, position };
}

/**
 * Get daily curated zaps (fallback content)
 * Uses today's date in YYYY-MM-DD format (UTC)
 */
async function getDailyCuratedZaps(): Promise<string[]> {
  try {
    // Get today's date in YYYY-MM-DD format (UTC)
    const today = new Date();
    const year = today.getUTCFullYear();
    const month = String(today.getUTCMonth() + 1).padStart(2, "0");
    const day = String(today.getUTCDate()).padStart(2, "0");
    const dateString = `${year}-${month}-${day}`;

    const curatedDoc = await db
      .collection(DAILY_CURATED_ZAPS_COLLECTION)
      .doc(dateString)
      .get();

    if (curatedDoc.exists) {
      const data = curatedDoc.data();
      return (data?.zapIds as string[]) || [];
    }

    // Fallback: try previous day's curated zaps if today's doesn't exist yet
    const yesterday = new Date(today);
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    const yesterdayYear = yesterday.getUTCFullYear();
    const yesterdayMonth = String(yesterday.getUTCMonth() + 1).padStart(2, "0");
    const yesterdayDay = String(yesterday.getUTCDate()).padStart(2, "0");
    const yesterdayString = `${yesterdayYear}-${yesterdayMonth}-${yesterdayDay}`;

    const yesterdayDoc = await db
      .collection(DAILY_CURATED_ZAPS_COLLECTION)
      .doc(yesterdayString)
      .get();

    if (yesterdayDoc.exists) {
      const data = yesterdayDoc.data();
      functions.logger.info(
        `Using yesterday's curated zaps (${yesterdayString}) as fallback`
      );
      return (data?.zapIds as string[]) || [];
    }

    // Fallback: return empty array
    return [];
  } catch (error) {
    functions.logger.error("Error fetching daily curated zaps:", error);
    return [];
  }
}

/**
 * Generate personalized recommendations for a user
 * Handles new users, low-interaction users, and full personalization
 */
async function generatePersonalizedRecommendations(
  userId: string,
  isNewUser: boolean = false,
  interactionCount: number = 0
): Promise<{ zapIds: string[]; isFallback: boolean }> {
  // Fetch user profile data in parallel
  const [
    tagsLiked,
    usersLiked,
    followedUserIds,
    viewedZapIds,
    blockedPostIds,
    blockedUserIds,
    usersWithBlockedPosts,
  ] = await Promise.all([
    getUserTagPreferences(userId),
    getUserLikingPreferences(userId),
    getFollowedUserIds(userId),
    getViewedZapIds(userId),
    getBlockedPostIds(userId),
    getBlockedUserIdsForContent(userId),
    getUsersWithBlockedPosts(userId),
  ]);

  const userProfile: UserProfile = {
    tagsLiked,
    usersLiked,
    followedUserIds,
    viewedZapIds,
    interactionCount,
    usersWithBlockedPosts,
  };

  // New user or zero interactions: return curated + trending mix
  if (isNewUser || interactionCount === 0) {
    functions.logger.info(
      `New user ${userId} detected, using curated + trending mix`
    );

    const curatedZapIds = await getDailyCuratedZaps();
    const trendingCandidates = await fetchTrendingZaps(
      viewedZapIds,
      MAX_TRENDING_CANDIDATES
    );

    // Filter out blocked content from trending candidates
    const filteredTrendingCandidates = trendingCandidates.filter(
      (c) =>
        !blockedPostIds.has(c.zapId) && !blockedUserIds.has(c.userId)
    );

    // Mix: 70% curated, 30% trending
    const curatedCount = Math.floor(MAX_FINAL_RECOMMENDATIONS * 0.7);
    const trendingZapIds = filteredTrendingCandidates
      .slice(0, MAX_FINAL_RECOMMENDATIONS - curatedCount)
      .map((c) => c.zapId);

    let mixedZapIds = [
      ...curatedZapIds.slice(0, curatedCount),
      ...trendingZapIds,
    ].slice(0, MAX_FINAL_RECOMMENDATIONS);

    // Pad with random if needed
    if (mixedZapIds.length < MAX_FINAL_RECOMMENDATIONS) {
      const needed = MAX_FINAL_RECOMMENDATIONS - mixedZapIds.length;
      const randomIds = await getRandomSprinkleZapIds(mixedZapIds, needed);
      mixedZapIds = [...mixedZapIds, ...randomIds];
    }

    return { zapIds: mixedZapIds, isFallback: true };
  }

  // Low-interaction users (< 5): 50/50 mix of curated + light personalization
  if (interactionCount < MIN_INTERACTIONS_FOR_PERSONALIZATION) {
    functions.logger.info(
      `Low-interaction user ${userId} (${interactionCount} interactions), using 50/50 mix`
    );

    const curatedZapIds = await getDailyCuratedZaps();

    // Light personalization: just trending + followed
    const [trendingCandidates, followedCandidates] = await Promise.all([
      fetchTrendingZaps(
        viewedZapIds,
        Math.floor(MAX_TRENDING_CANDIDATES * 0.5)
      ),
      fetchFollowedUserZaps(
        followedUserIds,
        viewedZapIds,
        Math.floor(MAX_FOLLOWED_CANDIDATES * 0.5)
      ),
    ]);

    // Combine and deduplicate candidates, filtering blocked content
    const candidateMap = new Map<string, ZapCandidate>();
    [...trendingCandidates, ...followedCandidates].forEach((candidate) => {
      // Skip if already viewed, blocked, or from blocked user
      if (
        !viewedZapIds.has(candidate.zapId) &&
        !blockedPostIds.has(candidate.zapId) &&
        !blockedUserIds.has(candidate.userId)
      ) {
        candidateMap.set(candidate.zapId, candidate);
      }
    });

    const candidates = Array.from(candidateMap.values());
    const ranked = rankZaps(candidates, userProfile);
    const personalizedZapIds = ranked
      .slice(0, Math.floor(MAX_FINAL_RECOMMENDATIONS * 0.5))
      .map((c) => c.zapId);

    // Mix: 50% curated, 50% personalized
    let mixedZapIds = [
      ...curatedZapIds.slice(0, Math.floor(MAX_FINAL_RECOMMENDATIONS * 0.5)),
      ...personalizedZapIds,
    ].slice(0, MAX_FINAL_RECOMMENDATIONS);

    // Pad with random if needed
    if (mixedZapIds.length < MAX_FINAL_RECOMMENDATIONS) {
      const needed = MAX_FINAL_RECOMMENDATIONS - mixedZapIds.length;
      const randomIds = await getRandomSprinkleZapIds(mixedZapIds, needed);
      mixedZapIds = [...mixedZapIds, ...randomIds];
    }

    return { zapIds: mixedZapIds, isFallback: false };
  }

  // Full personalization for users with sufficient interactions
  functions.logger.info(
    `Full personalization for user ${userId} (${interactionCount} interactions)`
  );

  // Fetch all candidate sources in parallel
  const [trendingCandidates, followedCandidates, newPosts, olderPosts] =
    await Promise.all([
      fetchTrendingZaps(viewedZapIds, MAX_TRENDING_CANDIDATES),
      fetchFollowedUserZaps(
        followedUserIds,
        viewedZapIds,
        MAX_FOLLOWED_CANDIDATES
      ),
      fetchNewPosts(viewedZapIds, MAX_NEW_POSTS), // New posts for exploration
      fetchOlderPosts(viewedZapIds, MAX_OLDER_POSTS), // Older posts with lower probability
    ]);

  // Combine and deduplicate candidates, filtering blocked content
  const candidateMap = new Map<string, ZapCandidate>();
  [
    ...trendingCandidates,
    ...followedCandidates,
    ...newPosts,
    ...olderPosts,
  ].forEach((candidate) => {
    // Skip if already viewed, blocked, or from blocked user
    if (
      !viewedZapIds.has(candidate.zapId) &&
      !blockedPostIds.has(candidate.zapId) &&
      !blockedUserIds.has(candidate.userId)
    ) {
      candidateMap.set(candidate.zapId, candidate);
    }
  });

  const candidates = Array.from(candidateMap.values());

  // Rank candidates with full scoring
  const ranked = rankZaps(candidates, userProfile);

  // Get top ranked zaps
  let zapIds = ranked
    .slice(0, MAX_FINAL_RECOMMENDATIONS)
    .map((candidate) => candidate.zapId);

  // If we don't have enough recommendations, pad with random trending zaps
  if (zapIds.length < MAX_FINAL_RECOMMENDATIONS) {
    const needed = MAX_FINAL_RECOMMENDATIONS - zapIds.length;
    const randomIds = await getRandomSprinkleZapIds(zapIds, needed);
    zapIds = [...zapIds, ...randomIds];
  }

  return { zapIds, isFallback: false };
}

/**
 * Main callable function: generateZapRecommendations
 *
 * Supports pagination with perPage and lastZap parameters
 * Always generates large pool (500) of recommendations and caches them
 * Returns paginated slice based on lastZap position
 * Never shows "end" unless user has seen 95%+ of all zaps in system
 *
 * Phase A: Returns cached recommendations or daily curated zaps immediately
 * Phase B: Updates cache in background when near end of recommendations
 * Phase C: Tops up with similar/random zaps when cache exhausted
 */
export const generateZapRecommendations = functions
  .region("us-central1")
  .runWith({
    timeoutSeconds: 30,
    memory: "512MB",
  })
  .https.onCall(async (data, context) => {
    const startTime = Date.now();
    let userId: string | undefined;
    
    try {
      userId = data?.userId as string | undefined;
      const perPage = (data?.perPage as number) || DEFAULT_PER_PAGE;
      const lastZap = data?.lastZap as string | undefined;
      const lastViewedZapId = data?.lastViewedZapId as string | undefined; // From client

      functions.logger.info(
        `generateZapRecommendations called`,
        { userId, perPage, lastZap, lastViewedZapId, hasAuth: !!context.auth }
      );

      if (!userId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "userId is required"
        );
      }

      // Verify userId matches authenticated user if auth is present
      if (context.auth && context.auth.uid !== userId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "userId must match authenticated user"
        );
      }

    // Check user interaction count to determine if new/low-interaction user
    const interactionCount = await getUserInteractionCount(userId);
    const isNewUser = interactionCount === 0;

    // PHASE A: Try to return cached recommendations immediately
    const cached = await getCachedRecommendations(userId);

    if (cached && cached.zapIds.length > 0) {
      // Determine starting point: prioritize client's lastViewedZapId, then lastZap, then cached lastViewedZapId
      let startZapId: string | undefined = lastZap;
      
      if (lastViewedZapId && cached.zapIds.includes(lastViewedZapId)) {
        // Client sent lastViewedZapId and it exists in cache - use it
        startZapId = lastViewedZapId;
        functions.logger.info(
          `Using client's lastViewedZapId ${lastViewedZapId} for ${userId}`
        );
      } else if (!lastZap && cached.lastViewedZapId && cached.zapIds.includes(cached.lastViewedZapId)) {
        // No client input, but cache has lastViewedZapId - resume from there
        startZapId = cached.lastViewedZapId;
        functions.logger.info(
          `Resuming from cached lastViewedZapId ${cached.lastViewedZapId} for ${userId}`
        );
      }

      // Get paginated slice
      const paginated = getPaginatedSlice(cached.zapIds, startZapId, perPage);

      // If cache is exhausted, return what we have and top up in background
      // Don't block the response with slow operations
      if (!paginated.hasMore || paginated.zapIds.length < perPage) {
        functions.logger.info(
          `Cache near exhaustion for ${userId} (remaining: ${paginated.zapIds.length}), will top up in background`
        );

        // Top up in background (don't await - return immediately)
        Promise.all([
          getViewedZapIds(userId),
          getUserTagPreferences(userId),
        ])
          .then(async ([viewedZapIds, tagsLiked]) => {
            const allSeenZaps = new Set([
              ...cached.zapIds,
              ...Array.from(viewedZapIds),
            ]);

            // Skip expensive totalZapCount check - just try to top up
            let topUpIds: string[] = [];

            // Try similar zaps by tags (with timeout)
            if (Object.keys(tagsLiked).length > 0) {
              try {
                const similarCandidates = await Promise.race([
                  fetchSimilarZapsByTags(
                    cached.zapIds,
                    tagsLiked,
                    allSeenZaps,
                    MIN_RANDOM_TOPUP * 2
                  ),
                  new Promise<ZapCandidate[]>((resolve) =>
                    setTimeout(() => resolve([]), 5000)
                  ), // 5s timeout
                ]);
                topUpIds = similarCandidates.map((c) => c.zapId);
              } catch (error) {
                functions.logger.warn(
                  `Similar zaps fetch timed out for ${userId}`,
                  error
                );
              }
            }

            // If not enough similar zaps, add random ones (with timeout)
            if (topUpIds.length < MIN_RANDOM_TOPUP) {
              try {
                const randomIds = await Promise.race([
                  getRandomSprinkleZapIds(
                    [...cached.zapIds, ...topUpIds],
                    MIN_RANDOM_TOPUP - topUpIds.length
                  ),
                  new Promise<string[]>((resolve) =>
                    setTimeout(() => resolve([]), 5000)
                  ), // 5s timeout
                ]);
                topUpIds = [...topUpIds, ...randomIds];
              } catch (error) {
                functions.logger.warn(
                  `Random zaps fetch timed out for ${userId}`,
                  error
                );
              }
            }

            if (topUpIds.length > 0) {
              const updatedZapIds = [...cached.zapIds, ...topUpIds].slice(
                0,
                MAX_CACHE_SIZE
              );

              await saveRecommendationsToCache(
                userId!,
                updatedZapIds,
                cached.isFallback,
                cached.position
              );
            }
          })
          .catch((error) => {
            functions.logger.error(
              `Background top-up failed for ${userId}:`,
              error
            );
          });
      }

      functions.logger.info(
        `Returning cached recommendations for ${userId} (${paginated.zapIds.length} zaps, position: ${paginated.position}/${cached.zapIds.length}, fallback: ${cached.isFallback})`
      );

      let responseZapIds = paginated.zapIds;
      let responseHasMore = paginated.hasMore;
      let responseNextLastZap = paginated.nextLastZap;

      // Always ensure we have more content (skip expensive checks, top up in background)
      if (!responseHasMore) {
        // Return hasMore: true to prevent "end" message, top up in background
        responseHasMore = true;
        
        // Top up in background (don't block response)
        Promise.all([
          getViewedZapIds(userId!),
          getUserTagPreferences(userId!),
        ])
          .then(async ([viewedZapIds, tagsLiked]) => {
            const allSeenZaps = new Set([
              ...cached.zapIds,
              ...Array.from(viewedZapIds),
            ]);

            let topUpIds: string[] = [];

            // Try similar zaps first (with timeout)
            if (Object.keys(tagsLiked).length > 0) {
              try {
                const similarCandidates = await Promise.race([
                  fetchSimilarZapsByTags(
                    cached.zapIds,
                    tagsLiked,
                    allSeenZaps,
                    MIN_RANDOM_TOPUP * 2
                  ),
                  new Promise<ZapCandidate[]>((resolve) =>
                    setTimeout(() => resolve([]), 5000)
                  ),
                ]);
                topUpIds = similarCandidates.map((c) => c.zapId);
              } catch (error) {
                functions.logger.warn(
                  `Similar zaps fetch timed out for ${userId}`,
                  error
                );
              }
            }

            // Add random if needed (with timeout)
            if (topUpIds.length < MIN_RANDOM_TOPUP) {
              try {
                const randomIds = await Promise.race([
                  getRandomSprinkleZapIds(
                    [...cached.zapIds, ...topUpIds],
                    MIN_RANDOM_TOPUP - topUpIds.length
                  ),
                  new Promise<string[]>((resolve) =>
                    setTimeout(() => resolve([]), 5000)
                  ),
                ]);
                topUpIds = [...topUpIds, ...randomIds];
              } catch (error) {
                functions.logger.warn(
                  `Random zaps fetch timed out for ${userId}`,
                  error
                );
              }
            }

            if (topUpIds.length > 0) {
              await saveRecommendationsToCache(
                userId!,
                topUpIds,
                cached.isFallback,
                paginated.position,
                { mergeStrategy: "append" }
              );
            }
          })
          .catch((error) => {
            functions.logger.error(
              `Background top-up failed for ${userId}:`,
              error
            );
          });
      }

      // PHASE B: If near end of recommendations, refresh in background
      if (paginated.position >= PAGINATION_REFRESH_THRESHOLD) {
        functions.logger.info(
          `User ${userId} near end of recommendations (${paginated.position}), refreshing in background`
        );

        generatePersonalizedRecommendations(userId!, isNewUser, interactionCount)
          .then((result) => {
            if (result.zapIds.length > 0) {
              return saveRecommendationsToCache(
                userId!,
                result.zapIds,
                result.isFallback,
                paginated.position, // Preserve current position
                { mergeStrategy: "append" }
              );
            }
            return null;
          })
          .catch((error) => {
            functions.logger.error(
              `Background cache refresh failed for ${userId}:`,
              error
            );
          });
      } else {
        // Normal background refresh (not urgent)
        generatePersonalizedRecommendations(userId!, isNewUser, interactionCount)
          .then((result) => {
            if (result.zapIds.length > 0) {
              return saveRecommendationsToCache(
                userId!,
                result.zapIds,
                result.isFallback,
                cached.position,
                { mergeStrategy: "append" }
              );
            }
            return null;
          })
          .catch((error) => {
            functions.logger.error(
              `Background cache update failed for ${userId}:`,
              error
            );
          });
      }

      // Update cache with lastViewedZapId (from client or last zap in response)
      const zapIdToSave = lastViewedZapId || responseZapIds[responseZapIds.length - 1] || null;
      if (zapIdToSave && cached.zapIds.includes(zapIdToSave)) {
        try {
          await db
            .collection(CACHED_RECOMMENDATIONS_COLLECTION)
            .doc(userId)
            .update({
              lastViewedZapId: zapIdToSave,
              lastViewedPosition: paginated.position,
            });
        } catch (error) {
          functions.logger.warn(
            `Failed to update lastViewedZapId for ${userId}:`,
            error
          );
        }
      }

      return {
        zapIds: responseZapIds,
        hasMore: responseHasMore,
        nextLastZap: responseNextLastZap,
        source: cached.isFallback ? "cache_fallback" : "cache",
        generatedAt: new Date().toISOString(),
      };
    }

    // No valid cache: try daily curated zaps as immediate fallback
    const curatedZapIds = await getDailyCuratedZaps();

    if (curatedZapIds && curatedZapIds.length > 0) {
      // Get paginated slice from curated zaps
      const paginated = getPaginatedSlice(curatedZapIds, lastZap, perPage);

      functions.logger.info(
        `Returning daily curated zaps for ${userId} (${paginated.zapIds.length} zaps, position: ${paginated.position}/${curatedZapIds.length})`
      );

      // PHASE B: Generate personalized recommendations in background
      generatePersonalizedRecommendations(userId!, isNewUser, interactionCount)
        .then((result) => {
          if (result.zapIds.length > 0) {
            return saveRecommendationsToCache(
              userId!,
              result.zapIds,
              result.isFallback,
              paginated.position
            );
          }
          return null;
        })
        .catch((error) => {
          functions.logger.error(
            `Background recommendation generation failed for ${userId}:`,
            error
          );
        });

      let responseZapIds = paginated.zapIds;
      let responseHasMore = paginated.hasMore;
      let responseNextLastZap = paginated.nextLastZap;

      // Always ensure we have more content (skip expensive checks, top up in background)
      if (!responseHasMore) {
        // Return hasMore: true to prevent "end" message, top up in background
        responseHasMore = true;
        
        // Top up in background (don't block response)
        Promise.all([
          getViewedZapIds(userId!),
          getUserTagPreferences(userId!),
        ])
          .then(async ([viewedZapIds, tagsLiked]) => {
            const allSeenZaps = new Set([
              ...curatedZapIds,
              ...Array.from(viewedZapIds),
            ]);

            let topUpIds: string[] = [];

            if (Object.keys(tagsLiked).length > 0) {
              try {
                const similarCandidates = await Promise.race([
                  fetchSimilarZapsByTags(
                    curatedZapIds,
                    tagsLiked,
                    allSeenZaps,
                    MIN_RANDOM_TOPUP * 2
                  ),
                  new Promise<ZapCandidate[]>((resolve) =>
                    setTimeout(() => resolve([]), 5000)
                  ),
                ]);
                topUpIds = similarCandidates.map((c) => c.zapId);
              } catch (error) {
                functions.logger.warn(
                  `Similar zaps fetch timed out for ${userId} (curated path)`,
                  error
                );
              }
            }

            if (topUpIds.length < MIN_RANDOM_TOPUP) {
              try {
                const randomIds = await Promise.race([
                  getRandomSprinkleZapIds(
                    [...curatedZapIds, ...topUpIds],
                    MIN_RANDOM_TOPUP - topUpIds.length
                  ),
                  new Promise<string[]>((resolve) =>
                    setTimeout(() => resolve([]), 5000)
                  ),
                ]);
                topUpIds = [...topUpIds, ...randomIds];
              } catch (error) {
                functions.logger.warn(
                  `Random zaps fetch timed out for ${userId} (curated path)`,
                  error
                );
              }
            }

            // Save to cache for next time (don't update response since it's already returned)
            if (topUpIds.length > 0) {
              await saveRecommendationsToCache(
                userId!,
                topUpIds,
                false,
                0,
                { mergeStrategy: "append" }
              );
            }
          })
          .catch((error) => {
            functions.logger.error(
              `Background top-up failed for ${userId} (curated path):`,
              error
            );
          });
      }

      // Update cache with lastViewedZapId if provided
      if (lastViewedZapId) {
        try {
          const cacheRef = db
            .collection(CACHED_RECOMMENDATIONS_COLLECTION)
            .doc(userId);
          const cacheDoc = await cacheRef.get();
          
          if (cacheDoc.exists) {
            const cacheData = cacheDoc.data();
            const cacheZapIds = (cacheData?.zapIds as string[]) || [];
            
            if (cacheZapIds.includes(lastViewedZapId)) {
              await cacheRef.update({
                lastViewedZapId: lastViewedZapId,
              });
            }
          }
        } catch (error) {
          functions.logger.warn(
            `Failed to update lastViewedZapId for ${userId} (curated path):`,
            error
          );
        }
      }

      return {
        zapIds: responseZapIds,
        hasMore: responseHasMore,
        nextLastZap: responseNextLastZap,
        source: "curated",
        generatedAt: new Date().toISOString(),
      };
    }

    // Last resort: generate recommendations synchronously (slower but ensures response)
    functions.logger.warn(
      `No cache or curated zaps available for ${userId}, generating synchronously`
    );

    const result = await generatePersonalizedRecommendations(
      userId,
      isNewUser,
      interactionCount
    );

    const allZapIds = result.zapIds.length > 0 ? result.zapIds : curatedZapIds;
    const paginated = getPaginatedSlice(allZapIds, lastZap, perPage);

    // Save to cache for next time
    if (result.zapIds.length > 0) {
      await saveRecommendationsToCache(
        userId,
        result.zapIds,
        result.isFallback,
        paginated.position
      );
    }

    const elapsed = Date.now() - startTime;
    functions.logger.info(
      `Generated recommendations for ${userId} in ${elapsed}ms (${paginated.zapIds.length} zaps, position: ${paginated.position}/${allZapIds.length}, fallback: ${result.isFallback})`
    );

    let responseZapIds = paginated.zapIds;
    let responseHasMore = paginated.hasMore;
    let responseNextLastZap = paginated.nextLastZap;

    if (!responseHasMore) {
      const topUpCount = Math.max(
        MIN_RANDOM_TOPUP,
        perPage - responseZapIds.length
      );
      const sprinkle = await getRandomSprinkleZapIds(
        allZapIds.concat(responseZapIds),
        topUpCount
      );

      if (sprinkle.length > 0) {
        responseZapIds = [...responseZapIds, ...sprinkle];
        responseHasMore = true;
        responseNextLastZap = sprinkle[sprinkle.length - 1];
      }
    }

    return {
      zapIds: responseZapIds,
      hasMore: responseHasMore,
      nextLastZap: responseNextLastZap,
      source: result.isFallback
        ? "fallback"
        : result.zapIds.length > 0
        ? "personalized"
        : "curated",
      generatedAt: new Date().toISOString(),
    };
    } catch (error) {
      const elapsed = Date.now() - startTime;
      functions.logger.error(
        `generateZapRecommendations failed for ${userId} after ${elapsed}ms`,
        {
          error: error instanceof Error ? error.message : String(error),
          stack: error instanceof Error ? error.stack : undefined,
          userId,
        }
      );

      // Re-throw HttpsError as-is (these are expected errors)
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Wrap unexpected errors
      throw new functions.https.HttpsError(
        "internal",
        `Internal error: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  });
