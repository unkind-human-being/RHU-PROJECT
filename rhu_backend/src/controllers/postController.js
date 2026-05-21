const Post = require("../models/Post");
const RHU = require("../models/RHU");
const Barangay = require("../models/Barangay");
const { asyncHandler } = require("../middleware/errorMiddleware");
const {
  USER_ROLES,
  POST_STATUS,
  AUDIENCE_SCOPE,
} = require("../utils/constants");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);
const getUserBarangayId = (req) => getIdString(req.user?.barangay);

const checkPostAccess = (req, post) => {
  if (!req.user) {
    if (
      post.status === POST_STATUS.PUBLISHED &&
      post.audienceScope === AUDIENCE_SCOPE.PUBLIC
    ) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "This post is not available for public access.",
    };
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  const postRhuId = getIdString(post.rhu);
  const postBarangayId = getIdString(post.barangay);

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === postRhuId) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access posts under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (post.audienceScope === AUDIENCE_SCOPE.PUBLIC) {
      return {
        allowed: true,
      };
    }

    if (
      getUserRhuId(req) === postRhuId &&
      (!postBarangayId || getUserBarangayId(req) === postBarangayId)
    ) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access posts under your assigned barangay.",
    };
  }

  if (
    req.user.role === USER_ROLES.PUBLIC_USER &&
    post.status === POST_STATUS.PUBLISHED &&
    post.audienceScope === AUDIENCE_SCOPE.PUBLIC
  ) {
    return {
      allowed: true,
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to access this post.",
  };
};

const buildPublicPostFilter = (req) => {
  const filter = {
    status: POST_STATUS.PUBLISHED,
    audienceScope: AUDIENCE_SCOPE.PUBLIC,
    isDeleted: false,
  };

  if (req.query.rhu) {
    filter.rhu = req.query.rhu;
  }

  if (req.query.barangay) {
    filter.barangay = req.query.barangay;
  }

  if (req.query.type) {
    filter.type = req.query.type;
  }

  if (req.query.search) {
    const searchRegex = new RegExp(req.query.search.trim(), "i");

    filter.$or = [
      { title: searchRegex },
      { content: searchRegex },
      { tags: searchRegex },
    ];
  }

  return filter;
};

const buildStaffPostFilter = (req) => {
  const filter = {
    isDeleted: false,
  };

  if (req.query.status) {
    filter.status = req.query.status;
  }

  if (req.query.type) {
    filter.type = req.query.type;
  }

  if (req.query.audienceScope) {
    filter.audienceScope = req.query.audienceScope;
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    filter.rhu = getUserRhuId(req);
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    filter.rhu = getUserRhuId(req);

    filter.$or = [
      { audienceScope: AUDIENCE_SCOPE.PUBLIC },
      { barangay: getUserBarangayId(req) },
      { barangay: null },
    ];
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    if (req.query.rhu) {
      filter.rhu = req.query.rhu;
    }

    if (req.query.barangay) {
      filter.barangay = req.query.barangay;
    }
  }

  if (req.query.search) {
    const searchRegex = new RegExp(req.query.search.trim(), "i");

    const searchConditions = [
      { title: searchRegex },
      { content: searchRegex },
      { tags: searchRegex },
    ];

    if (filter.$or) {
      filter.$and = [
        {
          $or: filter.$or,
        },
        {
          $or: searchConditions,
        },
      ];

      delete filter.$or;
    } else {
      filter.$or = searchConditions;
    }
  }

  return filter;
};

const validatePostLocation = async ({ rhu, barangay }) => {
  if (!rhu) {
    throw new Error("RHU is required.");
  }

  const existingRHU = await RHU.findById(rhu);

  if (!existingRHU || !existingRHU.isActive) {
    throw new Error("Selected RHU does not exist or is inactive.");
  }

  if (barangay) {
    const existingBarangay = await Barangay.findById(barangay);

    if (!existingBarangay || !existingBarangay.isActive) {
      throw new Error("Selected barangay does not exist or is inactive.");
    }

    if (existingBarangay.rhu.toString() !== rhu.toString()) {
      throw new Error("Selected barangay does not belong to the selected RHU.");
    }
  }
};

const checkLocationAccess = (req, rhu, barangay = null) => {
  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === rhu.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only manage posts under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (
      getUserRhuId(req) === rhu.toString() &&
      (!barangay || getUserBarangayId(req) === barangay.toString())
    ) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only manage posts under your assigned barangay.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to manage posts.",
  };
};

const getPublicPosts = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = buildPublicPostFilter(req);

  const [posts, total] = await Promise.all([
    Post.find(filter)
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .populate("createdBy", "fullName role")
      .sort({ isPinned: -1, publishedAt: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit),
    Post.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Public posts fetched successfully.",
    count: posts.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: posts,
  });
});

const getPosts = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = buildStaffPostFilter(req);

  const [posts, total] = await Promise.all([
    Post.find(filter)
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .populate("createdBy", "fullName email role")
      .populate("updatedBy", "fullName email role")
      .sort({ isPinned: -1, publishedAt: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit),
    Post.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Posts fetched successfully.",
    count: posts.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: posts,
  });
});

const getPostById = asyncHandler(async (req, res) => {
  const post = await Post.findById(req.params.id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role")
    .populate("updatedBy", "fullName email role");

  if (!post || post.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Post not found.",
    });
  }

  const access = checkPostAccess(req, {
    ...post.toObject(),
    rhu: post.rhu?._id || post.rhu,
    barangay: post.barangay?._id || post.barangay,
  });

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  return res.status(200).json({
    success: true,
    message: "Post fetched successfully.",
    data: post,
  });
});

const createPost = asyncHandler(async (req, res) => {
  const {
    title,
    content,
    type,
    status,
    audienceScope,
    rhu,
    barangay,
    imageUrl,
    attachments,
    tags,
    isPinned,
    publishAt,
  } = req.body;

  try {
    await validatePostLocation({ rhu, barangay });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }

  const access = checkLocationAccess(req, rhu, barangay);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const post = await Post.create({
    title,
    content,
    type,
    status,
    audienceScope,
    rhu,
    barangay: barangay || null,
    imageUrl,
    attachments,
    tags,
    isPinned,
    publishAt,
    createdBy: req.userId,
  });

  const createdPost = await Post.findById(post._id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role");

  return res.status(201).json({
    success: true,
    message: "Post created successfully.",
    data: createdPost,
  });
});

const updatePost = asyncHandler(async (req, res) => {
  const post = await Post.findById(req.params.id);

  if (!post || post.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Post not found.",
    });
  }

  const access = checkPostAccess(req, post);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (post.createdBy.toString() !== req.userId.toString()) {
      return res.status(403).json({
        success: false,
        message: "Barangay health workers can only update posts they created.",
      });
    }
  }

  const allowedUpdates = [
    "title",
    "content",
    "type",
    "status",
    "audienceScope",
    "barangay",
    "imageUrl",
    "attachments",
    "tags",
    "isPinned",
    "publishAt",
  ];

  const updates = {};

  for (const field of allowedUpdates) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      updates[field] = req.body[field];
    }
  }

  if (updates.barangay) {
    try {
      await validatePostLocation({
        rhu: post.rhu,
        barangay: updates.barangay,
      });
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }

    const locationAccess = checkLocationAccess(req, post.rhu, updates.barangay);

    if (!locationAccess.allowed) {
      return res.status(403).json({
        success: false,
        message: locationAccess.message,
      });
    }
  }

  updates.updatedBy = req.userId;

  const updatedPost = await Post.findByIdAndUpdate(req.params.id, updates, {
    new: true,
    runValidators: true,
  })
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role")
    .populate("updatedBy", "fullName email role");

  return res.status(200).json({
    success: true,
    message: "Post updated successfully.",
    data: updatedPost,
  });
});

const publishPost = asyncHandler(async (req, res) => {
  const post = await Post.findById(req.params.id);

  if (!post || post.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Post not found.",
    });
  }

  const access = checkPostAccess(req, post);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  post.status = POST_STATUS.PUBLISHED;
  post.publishedAt = new Date();
  post.updatedBy = req.userId;
  await post.save();

  const publishedPost = await Post.findById(post._id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role")
    .populate("updatedBy", "fullName email role");

  return res.status(200).json({
    success: true,
    message: "Post published successfully.",
    data: publishedPost,
  });
});

const archivePost = asyncHandler(async (req, res) => {
  const post = await Post.findById(req.params.id);

  if (!post || post.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Post not found.",
    });
  }

  const access = checkPostAccess(req, post);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  post.status = POST_STATUS.ARCHIVED;
  post.archivedAt = new Date();
  post.updatedBy = req.userId;
  await post.save();

  return res.status(200).json({
    success: true,
    message: "Post archived successfully.",
  });
});

const deletePost = asyncHandler(async (req, res) => {
  const post = await Post.findById(req.params.id);

  if (!post || post.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Post not found.",
    });
  }

  const access = checkPostAccess(req, post);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  post.isDeleted = true;
  post.updatedBy = req.userId;
  await post.save();

  return res.status(200).json({
    success: true,
    message: "Post deleted successfully.",
  });
});

const incrementPostView = asyncHandler(async (req, res) => {
  const post = await Post.findById(req.params.id);

  if (
    !post ||
    post.isDeleted ||
    post.status !== POST_STATUS.PUBLISHED ||
    post.audienceScope !== AUDIENCE_SCOPE.PUBLIC
  ) {
    return res.status(404).json({
      success: false,
      message: "Public post not found.",
    });
  }

  post.viewCount += 1;
  await post.save();

  return res.status(200).json({
    success: true,
    message: "Post view recorded successfully.",
    data: {
      postId: post._id,
      viewCount: post.viewCount,
    },
  });
});

module.exports = {
  getPublicPosts,
  getPosts,
  getPostById,
  createPost,
  updatePost,
  publishPost,
  archivePost,
  deletePost,
  incrementPostView,
};