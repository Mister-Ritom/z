import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { rankZaps, UserProfile, ZapCandidate } from "./ranking";

const db = admin.firestore();

const SHORTS_COLLECTION = "shorts";
const FOLLOWING_COLLECTION = "following";
const USER_INTERACTIONS_COLLECTION = "user_interactions";
const ANALYTICS_COLLECTION = "analytics";
const CACHED_SHORTS_COLLECTION = "cached_short_recommendations";
const DAILY_CURATED_SHORTS_COLLECTION = "daily_curated_shorts";

const MAX_SHORT_CANDIDATES = 500;
const MAX_SHORT_RECOMMENDATIONS = 500; // Large pool for endless feed
const MAX_SHORT_CACHE_SIZE = 1000; // Increased for endless feed
const SHORTS_DEFAULT_PER_PAGE = 15;
const SHORTS_REFRESH_THRESHOLD = 60;
const MIN_RANDOM_SHORT_TOPUP = 5;

interface ShortCacheEntry {
  shortIds: string[];
  isFallback: boolean;
  position: number;
  lastViewedZapId: string | null;
}

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

async function getFollowedUserIds(userId: string): Promise<string[]> {
  try {
    const followingSnapshot = await db
      .collection(FOLLOWING_COLLECTION)
      .doc(userId)
      .collection("users")
      .select()
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

async function getViewedShortIds(userId: string): Promise<Set<string>> {
  try {
    const viewedSnapshot = await db
      .collection(USER_INTERACTIONS_COLLECTION)
      .doc(userId)
      .collection(SHORTS_COLLECTION)
      .where("viewed", "==", true)
      .select()
      .limit(1000)
      .get();

    return new Set(viewedSnapshot.docs.map((doc) => doc.id));
  } catch (error) {
    functions.logger.warn(`Error fetching viewed shorts for ${userId}:`, error);
    return new Set();
  }
}

async function getShortInteractionCount(userId: string): Promise<number> {
  try {
    const likedSnapshot = await db
      .collection(USER_INTERACTIONS_COLLECTION)
      .doc(userId)
      .collection(SHORTS_COLLECTION)
      .where("liked", "==", true)
      .select()
      .limit(100)
      .get();

    const resharedSnapshot = await db
      .collection(USER_INTERACTIONS_COLLECTION)
      .doc(userId)
      .collection(SHORTS_COLLECTION)
      .where("reshared", "==", true)
      .select()
      .limit(100)
      .get();

    const viewedSnapshot = await db
      .collection(USER_INTERACTIONS_COLLECTION)
      .doc(userId)
      .collection(SHORTS_COLLECTION)
      .where("viewed", "==", true)
      .select()
      .limit(100)
      .get();

    return Math.min(
      likedSnapshot.size +
        resharedSnapshot.size +
        Math.min(viewedSnapshot.size, 50),
      300
    );
  } catch (error) {
    functions.logger.warn(
      `Error counting short interactions for ${userId}:`,
      error
    );
    return 0;
  }
}

async function fetchAnalyticsForShorts(
  docIds: string[]
): Promise<admin.firestore.DocumentSnapshot<admin.firestore.DocumentData>[]> {
  return Promise.all(
    docIds.map((id) =>
      db
        .collection(ANALYTICS_COLLECTION)
        .doc(SHORTS_COLLECTION)
        .collection(SHORTS_COLLECTION)
        .doc(id)
        .get()
    )
  );
}

function toCandidate(
  doc: admin.firestore.QueryDocumentSnapshot,
  analyticsDoc: admin.firestore.DocumentSnapshot
): ZapCandidate | null {
  const data = doc.data();

  if (data?.isDeleted) return null;

  const analyticsData = analyticsDoc.data() || {};

  return {
    zapId: doc.id,
    userId: data.userId as string,
    hashtags: (data.hashtags as string[]) || [],
    createdAt: data.createdAt as admin.firestore.Timestamp,
    likesCount: (data.likesCount as number) || 0,
    rezapsCount: (data.rezapsCount as number) || 0,
    views: (analyticsData.views as number) || 0,
    score: 0,
  };
}

async function fetchRecentShorts(
  excludeIds: Set<string>,
  limit: number
): Promise<ZapCandidate[]> {
  try {
    const snapshot = await db
      .collection(SHORTS_COLLECTION)
      .where("isDeleted", "==", false)
      .orderBy("createdAt", "desc")
      .limit(limit * 4)
      .get();

    if (snapshot.empty) return [];

    const analyticsDocs = await fetchAnalyticsForShorts(
      snapshot.docs.map((doc) => doc.id)
    );

    const candidates: ZapCandidate[] = [];

    for (
      let i = 0;
      i < snapshot.docs.length && candidates.length < limit;
      i++
    ) {
      const doc = snapshot.docs[i];
      if (excludeIds.has(doc.id)) continue;

      const candidate = toCandidate(doc, analyticsDocs[i]);
      if (candidate) {
        candidates.push(candidate);
      }
    }

    return candidates;
  } catch (error) {
    functions.logger.error("Error fetching recent shorts:", error);
    return [];
  }
}

async function fetchFollowedShorts(
  followedUserIds: string[],
  excludeIds: Set<string>,
  limit: number
): Promise<ZapCandidate[]> {
  if (followedUserIds.length === 0) return [];

  try {
    const candidates: ZapCandidate[] = [];
    const batchSize = 10;

    for (let i = 0; i < followedUserIds.length; i += batchSize) {
      const batch = followedUserIds.slice(i, i + batchSize);

      const snapshot = await db
        .collection(SHORTS_COLLECTION)
        .where("isDeleted", "==", false)
        .where("userId", "in", batch)
        .orderBy("createdAt", "desc")
        .limit(Math.ceil(limit / (followedUserIds.length / batchSize || 1)))
        .get();

      if (snapshot.empty) continue;

      const analyticsDocs = await fetchAnalyticsForShorts(
        snapshot.docs.map((doc) => doc.id)
      );

      for (let j = 0; j < snapshot.docs.length; j++) {
        const doc = snapshot.docs[j];
        if (excludeIds.has(doc.id)) continue;

        const candidate = toCandidate(doc, analyticsDocs[j]);
        if (candidate) {
          candidates.push(candidate);
        }

        if (candidates.length >= limit) break;
      }

      if (candidates.length >= limit) break;
    }

    return candidates;
  } catch (error) {
    functions.logger.error("Error fetching followed shorts:", error);
    return [];
  }
}

async function getCachedShortRecommendations(
  userId: string
): Promise<ShortCacheEntry | null> {
  try {
    const cacheDoc = await db
      .collection(CACHED_SHORTS_COLLECTION)
      .doc(userId)
      .get();

    if (!cacheDoc.exists) return null;

    const data = cacheDoc.data();
    if (!data?.updatedAt) return null;

    return {
      shortIds: (data.shortIds as string[]) || [],
      isFallback: (data.isFallback as boolean) || false,
      position: (data.lastPosition as number) || 0,
      lastViewedZapId: (data.lastViewedZapId as string) || null,
    };
  } catch (error) {
    functions.logger.warn(`Error fetching short cache for ${userId}:`, error);
    return null;
  }
}

/**
 * Fetch similar shorts based on tags
 */
async function fetchSimilarShortsByTags(
  existingShortIds: string[],
  userTags: Record<string, number>,
  excludeShortIds: Set<string>,
  limit: number
): Promise<ZapCandidate[]> {
  if (Object.keys(userTags).length === 0 || limit <= 0) return [];

  try {
    const topTags = Object.entries(userTags)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([tag]) => tag);

    if (topTags.length === 0) return [];

    const candidates: ZapCandidate[] = [];

    for (const tag of topTags) {
      if (candidates.length >= limit) break;

      const tagSnapshot = await db
        .collection(SHORTS_COLLECTION)
        .where("isDeleted", "==", false)
        .where("hashtags", "array-contains", tag)
        .orderBy("createdAt", "desc")
        .limit(limit * 2)
        .get();

      if (tagSnapshot.empty) continue;

      const analyticsDocs = await fetchAnalyticsForShorts(
        tagSnapshot.docs.map((doc) => doc.id)
      );

      for (let i = 0; i < tagSnapshot.docs.length && candidates.length < limit; i++) {
        const doc = tagSnapshot.docs[i];
        if (excludeShortIds.has(doc.id)) continue;

        const candidate = toCandidate(doc, analyticsDocs[i]);
        if (candidate) {
          candidates.push(candidate);
        }
      }
    }

    return candidates.slice(0, limit);
  } catch (error) {
    functions.logger.error("Error fetching similar shorts by tags:", error);
    return [];
  }
}

/**
 * Get random shorts as last resort
 */
async function getRandomShortSprinkleIds(
  existingShortIds: string[],
  count: number
): Promise<string[]> {
  if (count <= 0) return [];

  try {
    const excludeSet = new Set(existingShortIds);
    const randomShorts = await fetchRecentShorts(
      excludeSet,
      Math.max(count * 3, 100)
    );

    // Shuffle and take random selection
    const shuffled = randomShorts.sort(() => Math.random() - 0.5);
    return shuffled.slice(0, count).map((candidate) => candidate.zapId);
  } catch (error) {
    functions.logger.error("Error fetching random short sprinkle:", error);
    return [];
  }
}


async function saveShortRecommendationsToCache(
  userId: string,
  shortIds: string[],
  isFallback: boolean,
  position: number,
  append: boolean
): Promise<void> {
  let finalShortIds = shortIds.slice(0, MAX_SHORT_CACHE_SIZE);

  if (append) {
    try {
      const existingDoc = await db
        .collection(CACHED_SHORTS_COLLECTION)
        .doc(userId)
        .get();
      const existingShortIds = (
        (existingDoc.data()?.shortIds as string[]) || []
      ).slice();

      if (existingShortIds.length >= MAX_SHORT_CACHE_SIZE) {
        finalShortIds = shortIds.slice(0, MAX_SHORT_CACHE_SIZE);
      } else {
        const seen = new Set(existingShortIds);
        const merged = [...existingShortIds];
        shortIds.forEach((id) => {
          if (!seen.has(id)) {
            merged.push(id);
            seen.add(id);
          }
        });

        if (merged.length > MAX_SHORT_CACHE_SIZE) {
          const overflow = merged.length - MAX_SHORT_CACHE_SIZE;
          finalShortIds = merged.slice(overflow);
        } else {
          finalShortIds = merged;
        }
      }
    } catch (error) {
      functions.logger.warn(
        `Failed to append short cache for ${userId}, replacing:`,
        error
      );
      finalShortIds = shortIds.slice(0, MAX_SHORT_CACHE_SIZE);
    }
  }

  const safePosition = Math.min(position, finalShortIds.length);

  await db.collection(CACHED_SHORTS_COLLECTION).doc(userId).set({
    shortIds: finalShortIds,
    isFallback,
    lastPosition: safePosition,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function getDailyCuratedShorts(): Promise<string[]> {
  try {
    const today = new Date();
    const year = today.getUTCFullYear();
    const month = String(today.getUTCMonth() + 1).padStart(2, "0");
    const day = String(today.getUTCDate()).padStart(2, "0");
    const dateString = `${year}-${month}-${day}`;

    const curatedDoc = await db
      .collection(DAILY_CURATED_SHORTS_COLLECTION)
      .doc(dateString)
      .get();

    if (curatedDoc.exists) {
      const data = curatedDoc.data();
      return (data?.shortIds as string[]) || [];
    }

    const yesterday = new Date(today);
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    const yYear = yesterday.getUTCFullYear();
    const yMonth = String(yesterday.getUTCMonth() + 1).padStart(2, "0");
    const yDay = String(yesterday.getUTCDate()).padStart(2, "0");
    const yesterdayString = `${yYear}-${yMonth}-${yDay}`;

    const yesterdayDoc = await db
      .collection(DAILY_CURATED_SHORTS_COLLECTION)
      .doc(yesterdayString)
      .get();

    if (yesterdayDoc.exists) {
      const data = yesterdayDoc.data();
      functions.logger.info(
        `Using yesterday's curated shorts (${yesterdayString}) as fallback`
      );
      return (data?.shortIds as string[]) || [];
    }

    return [];
  } catch (error) {
    functions.logger.error("Error fetching daily curated shorts:", error);
    return [];
  }
}

function getPaginatedSlice(
  allIds: string[],
  lastId: string | undefined,
  perPage: number
): {
  zapIds: string[];
  hasMore: boolean;
  nextLastZap: string | null;
  position: number;
} {
  let startIndex = 0;
  if (lastId) {
    const lastIndex = allIds.indexOf(lastId);
    if (lastIndex >= 0) {
      startIndex = lastIndex + 1;
    }
  }

  const endIndex = Math.min(startIndex + perPage, allIds.length);
  const zapIds = allIds.slice(startIndex, endIndex);
  const hasMore = endIndex < allIds.length;
  const nextLastZap =
    hasMore && zapIds.length > 0 ? zapIds[zapIds.length - 1] : null;

  return { zapIds, hasMore, nextLastZap, position: endIndex };
}

async function generateShortRecommendationsList(
  userId: string,
  interactionCount: number
): Promise<{ shortIds: string[]; isFallback: boolean }> {
  const [tagsLiked, usersLiked, followedUserIds, viewedShortIds] = await Promise.all([
    getUserTagPreferences(userId),
    getUserLikingPreferences(userId),
    getFollowedUserIds(userId),
    getViewedShortIds(userId),
  ]);

  const userProfile: UserProfile = {
    tagsLiked,
    usersLiked,
    followedUserIds,
    viewedZapIds: viewedShortIds,
    interactionCount,
  };

  const [recentShorts, followedShorts] = await Promise.all([
    fetchRecentShorts(viewedShortIds, MAX_SHORT_CANDIDATES),
    fetchFollowedShorts(
      followedUserIds,
      viewedShortIds,
      Math.floor(MAX_SHORT_CANDIDATES * 0.5)
    ),
  ]);

  const candidateMap = new Map<string, ZapCandidate>();
  [...recentShorts, ...followedShorts].forEach((candidate) => {
    if (!viewedShortIds.has(candidate.zapId)) {
      candidateMap.set(candidate.zapId, candidate);
    }
  });

  let candidates = Array.from(candidateMap.values());

  if (candidates.length === 0) {
    const fallbackIds = recentShorts
      .slice(0, MAX_SHORT_RECOMMENDATIONS)
      .map((c) => c.zapId);
    return { shortIds: fallbackIds, isFallback: true };
  }

  const ranked = rankZaps(candidates, userProfile);
  let shortIds = ranked
    .slice(0, MAX_SHORT_RECOMMENDATIONS)
    .map((candidate) => candidate.zapId);

  // If we don't have enough recommendations, pad with random shorts
  if (shortIds.length < MAX_SHORT_RECOMMENDATIONS) {
    const needed = MAX_SHORT_RECOMMENDATIONS - shortIds.length;
    const randomIds = await getRandomShortSprinkleIds(shortIds, needed);
    shortIds = [...shortIds, ...randomIds];
  }

  return { shortIds, isFallback: false };
}

export const generateShortRecommendations = functions
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
      const perPage = (data?.perPage as number) || SHORTS_DEFAULT_PER_PAGE;
      const lastZap = data?.lastZap as string | undefined;
      const lastViewedZapId = data?.lastViewedZapId as string | undefined; // From client

      functions.logger.info(
        `generateShortRecommendations called`,
        { userId, perPage, lastZap, lastViewedZapId, hasAuth: !!context.auth }
      );

      if (!userId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "userId is required"
        );
      }

      if (context.auth && context.auth.uid !== userId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "userId must match authenticated user"
        );
      }

      const interactionCount = await getShortInteractionCount(userId);
    const cached = await getCachedShortRecommendations(userId);

    if (cached && cached.shortIds.length > 0) {
      // Determine starting point: prioritize client's lastViewedZapId, then lastZap, then cached lastViewedZapId
      let startZapId: string | undefined = lastZap;
      
      if (lastViewedZapId && cached.shortIds.includes(lastViewedZapId)) {
        // Client sent lastViewedZapId and it exists in cache - use it
        startZapId = lastViewedZapId;
        functions.logger.info(
          `Using client's lastViewedZapId ${lastViewedZapId} for shorts ${userId}`
        );
      } else if (!lastZap && cached.lastViewedZapId && cached.shortIds.includes(cached.lastViewedZapId)) {
        // No client input, but cache has lastViewedZapId - resume from there
        startZapId = cached.lastViewedZapId;
        functions.logger.info(
          `Resuming from cached lastViewedZapId ${cached.lastViewedZapId} for shorts ${userId}`
        );
      }

      const paginated = getPaginatedSlice(cached.shortIds, startZapId, perPage);

      // If cache is exhausted, return what we have and top up in background
      // Don't block the response with slow operations
      if (!paginated.hasMore || paginated.zapIds.length < perPage) {
        functions.logger.info(
          `Cache near exhaustion for ${userId} (remaining: ${paginated.zapIds.length}), will top up in background`
        );

        // Top up in background (don't await - return immediately)
        Promise.all([
          getViewedShortIds(userId!),
          getUserTagPreferences(userId!),
        ])
          .then(async ([viewedShortIds, tagsLiked]) => {
            const allSeenShorts = new Set([
              ...cached.shortIds,
              ...Array.from(viewedShortIds),
            ]);

            // Skip expensive totalShortCount check - just try to top up
            let topUpIds: string[] = [];

            // Try similar shorts by tags (with timeout)
            if (Object.keys(tagsLiked).length > 0) {
              try {
                const similarCandidates = await Promise.race([
                  fetchSimilarShortsByTags(
                    cached.shortIds,
                    tagsLiked,
                    allSeenShorts,
                    MIN_RANDOM_SHORT_TOPUP * 2
                  ),
                  new Promise<ZapCandidate[]>((resolve) =>
                    setTimeout(() => resolve([]), 5000)
                  ), // 5s timeout
                ]);
                topUpIds = similarCandidates.map((c) => c.zapId);
              } catch (error) {
                functions.logger.warn(
                  `Similar shorts fetch timed out for ${userId}`,
                  error
                );
              }
            }

            // If not enough similar shorts, add random ones (with timeout)
            if (topUpIds.length < MIN_RANDOM_SHORT_TOPUP) {
              try {
                const randomIds = await Promise.race([
                  getRandomShortSprinkleIds(
                    [...cached.shortIds, ...topUpIds],
                    MIN_RANDOM_SHORT_TOPUP - topUpIds.length
                  ),
                  new Promise<string[]>((resolve) =>
                    setTimeout(() => resolve([]), 5000)
                  ), // 5s timeout
                ]);
                topUpIds = [...topUpIds, ...randomIds];
              } catch (error) {
                functions.logger.warn(
                  `Random shorts fetch timed out for ${userId}`,
                  error
                );
              }
            }

            if (topUpIds.length > 0) {
              const updatedShortIds = [...cached.shortIds, ...topUpIds].slice(
                0,
                MAX_SHORT_CACHE_SIZE
              );

              await saveShortRecommendationsToCache(
                userId!,
                updatedShortIds,
                cached.isFallback,
                cached.position,
                false
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

      if (paginated.position >= SHORTS_REFRESH_THRESHOLD) {
        generateShortRecommendationsList(userId!, interactionCount)
          .then((result) => {
            if (result.shortIds.length > 0) {
              return saveShortRecommendationsToCache(
                userId!,
                result.shortIds,
                result.isFallback,
                paginated.position,
                true
              );
            }
            return null;
          })
          .catch((error) => {
            functions.logger.error(
              `Background short cache refresh failed for ${userId}:`,
              error
            );
          });
      } else {
        generateShortRecommendationsList(userId!, interactionCount)
          .then((result) => {
            if (result.shortIds.length > 0) {
              return saveShortRecommendationsToCache(
                userId!,
                result.shortIds,
                result.isFallback,
                cached.position,
                true
              );
            }
            return null;
          })
          .catch((error) => {
            functions.logger.error(
              `Background short cache update failed for ${userId}:`,
              error
            );
          });
      }

      let responseZapIds = paginated.zapIds;
      let responseHasMore = paginated.hasMore;
      let responseNextLastZap = paginated.nextLastZap;

      // Always ensure we have more content (skip expensive checks, top up in background)
      if (!responseHasMore) {
        // Return hasMore: true to prevent "end" message, top up in background
        responseHasMore = true;
        
        // Top up in background (don't block response)
        Promise.all([
          getViewedShortIds(userId!),
          getUserTagPreferences(userId!),
        ])
          .then(async ([viewedShortIds, tagsLiked]) => {
            const allSeenShorts = new Set([
              ...cached.shortIds,
              ...Array.from(viewedShortIds),
            ]);

            let topUpIds: string[] = [];

            // Try similar shorts first (with timeout)
            if (Object.keys(tagsLiked).length > 0) {
              try {
                const similarCandidates = await Promise.race([
                  fetchSimilarShortsByTags(
                    cached.shortIds,
                    tagsLiked,
                    allSeenShorts,
                    MIN_RANDOM_SHORT_TOPUP * 2
                  ),
                  new Promise<ZapCandidate[]>((resolve) =>
                    setTimeout(() => resolve([]), 5000)
                  ),
                ]);
                topUpIds = similarCandidates.map((c) => c.zapId);
              } catch (error) {
                functions.logger.warn(
                  `Similar shorts fetch timed out for ${userId}`,
                  error
                );
              }
            }

            // Add random if needed (with timeout)
            if (topUpIds.length < MIN_RANDOM_SHORT_TOPUP) {
              try {
                const randomIds = await Promise.race([
                  getRandomShortSprinkleIds(
                    [...cached.shortIds, ...topUpIds],
                    MIN_RANDOM_SHORT_TOPUP - topUpIds.length
                  ),
                  new Promise<string[]>((resolve) =>
                    setTimeout(() => resolve([]), 5000)
                  ),
                ]);
                topUpIds = [...topUpIds, ...randomIds];
              } catch (error) {
                functions.logger.warn(
                  `Random shorts fetch timed out for ${userId}`,
                  error
                );
              }
            }

            if (topUpIds.length > 0) {
              await saveShortRecommendationsToCache(
                userId!,
                topUpIds,
                cached.isFallback,
                paginated.position,
                true
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

      // Update cache with lastViewedZapId (from client or last zap in response)
      const zapIdToSave = lastViewedZapId || responseZapIds[responseZapIds.length - 1] || null;
      if (zapIdToSave && cached.shortIds.includes(zapIdToSave)) {
        try {
          await db
            .collection(CACHED_SHORTS_COLLECTION)
            .doc(userId)
            .update({
              lastViewedZapId: zapIdToSave,
              lastViewedPosition: paginated.position,
            });
        } catch (error) {
          functions.logger.warn(
            `Failed to update lastViewedZapId for shorts ${userId}:`,
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

    const curatedShortIds = await getDailyCuratedShorts();

    if (curatedShortIds.length > 0) {
      const paginated = getPaginatedSlice(curatedShortIds, lastZap, perPage);

      generateShortRecommendationsList(userId, interactionCount)
        .then((result) => {
          if (result.shortIds.length > 0) {
            return saveShortRecommendationsToCache(
              userId!,
              result.shortIds,
              result.isFallback,
              paginated.position,
              false
            );
          }
          return null;
        })
        .catch((error) => {
          functions.logger.error(
            `Background short recommendation generation failed for ${userId}:`,
            error
          );
        });

      let responseZapIds = paginated.zapIds;
      let responseHasMore = paginated.hasMore;
      let responseNextLastZap = paginated.nextLastZap;

      if (!responseHasMore) {
        const topUpCount = Math.max(
          MIN_RANDOM_SHORT_TOPUP,
          perPage - responseZapIds.length
        );
        const sprinkle = await getRandomShortSprinkleIds(
          curatedShortIds.concat(responseZapIds),
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
        source: "curated",
        generatedAt: new Date().toISOString(),
      };
    }

    const result = await generateShortRecommendationsList(
      userId,
      interactionCount
    );

    if (result.shortIds.length > 0) {
      await saveShortRecommendationsToCache(
        userId,
        result.shortIds,
        result.isFallback,
        0,
        false
      );
    }

    const allShortIds =
      result.shortIds.length > 0 ? result.shortIds : curatedShortIds;
    const paginated = getPaginatedSlice(allShortIds, lastZap, perPage);

    let responseZapIds = paginated.zapIds;
    let responseHasMore = paginated.hasMore;
    let responseNextLastZap = paginated.nextLastZap;

    if (!responseHasMore) {
      const topUpCount = Math.max(
        MIN_RANDOM_SHORT_TOPUP,
        perPage - responseZapIds.length
      );
      const sprinkle = await getRandomShortSprinkleIds(
        allShortIds.concat(responseZapIds),
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
      source:
        result.isFallback && result.shortIds.length === 0
          ? "curated"
          : result.isFallback
          ? "fallback"
          : "personalized",
      generatedAt: new Date().toISOString(),
    };
    } catch (error) {
      const elapsed = Date.now() - startTime;
      functions.logger.error(
        `generateShortRecommendations failed for ${userId} after ${elapsed}ms`,
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
