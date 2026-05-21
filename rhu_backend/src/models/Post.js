const mongoose = require("mongoose");

const POST_TYPES = {
  ANNOUNCEMENT: "announcement",
  HEALTH_UPDATE: "health_update",
  EVENT_NOTICE: "event_notice",
  PUBLIC_ADVISORY: "public_advisory",
  ACHIEVEMENT: "achievement",
};

const POST_STATUS = {
  DRAFT: "draft",
  PUBLISHED: "published",
  ARCHIVED: "archived",
};

const AUDIENCE_SCOPE = {
  PUBLIC: "public",
  RHU_ONLY: "rhu_only",
  BARANGAY_ONLY: "barangay_only",
};

const postSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: [true, "Post title is required."],
      trim: true,
      maxlength: [180, "Post title cannot exceed 180 characters."],
      index: true,
    },

    content: {
      type: String,
      required: [true, "Post content is required."],
      trim: true,
      maxlength: [5000, "Post content cannot exceed 5000 characters."],
    },

    type: {
      type: String,
      enum: Object.values(POST_TYPES),
      default: POST_TYPES.ANNOUNCEMENT,
      index: true,
    },

    status: {
      type: String,
      enum: Object.values(POST_STATUS),
      default: POST_STATUS.DRAFT,
      index: true,
    },

    audienceScope: {
      type: String,
      enum: Object.values(AUDIENCE_SCOPE),
      default: AUDIENCE_SCOPE.PUBLIC,
      index: true,
    },

    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: [true, "Post must belong to an RHU."],
      index: true,
    },

    barangay: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Barangay",
      default: null,
      index: true,
    },

    imageUrl: {
      type: String,
      trim: true,
      default: "",
    },

    attachments: [
      {
        fileName: {
          type: String,
          trim: true,
          maxlength: [180, "File name cannot exceed 180 characters."],
        },
        fileUrl: {
          type: String,
          trim: true,
        },
        fileType: {
          type: String,
          trim: true,
          maxlength: [80, "File type cannot exceed 80 characters."],
        },
      },
    ],

    tags: [
      {
        type: String,
        trim: true,
        lowercase: true,
        maxlength: [50, "Tag cannot exceed 50 characters."],
      },
    ],

    isPinned: {
      type: Boolean,
      default: false,
      index: true,
    },

    publishAt: {
      type: Date,
      default: null,
      index: true,
    },

    publishedAt: {
      type: Date,
      default: null,
      index: true,
    },

    archivedAt: {
      type: Date,
      default: null,
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Post creator is required."],
      index: true,
    },

    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    viewCount: {
      type: Number,
      min: [0, "View count cannot be negative."],
      default: 0,
    },

    isDeleted: {
      type: Boolean,
      default: false,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

postSchema.index({
  status: 1,
  audienceScope: 1,
  publishedAt: -1,
});

postSchema.index({
  rhu: 1,
  status: 1,
  publishedAt: -1,
});

postSchema.index({
  rhu: 1,
  barangay: 1,
  status: 1,
  publishedAt: -1,
});

postSchema.index({
  title: "text",
  content: "text",
  tags: "text",
});

postSchema.pre("save", function () {
  if (this.status === POST_STATUS.PUBLISHED && !this.publishedAt) {
    this.publishedAt = new Date();
  }

  if (this.status === POST_STATUS.ARCHIVED && !this.archivedAt) {
    this.archivedAt = new Date();
  }
});

postSchema.statics.postTypes = POST_TYPES;
postSchema.statics.postStatuses = POST_STATUS;
postSchema.statics.audienceScopes = AUDIENCE_SCOPE;

module.exports = mongoose.model("Post", postSchema);