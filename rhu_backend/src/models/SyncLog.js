const mongoose = require("mongoose");

const SYNC_ENTITY_TYPES = {
  MEDICINE: "medicine",
  MEDICINE_TRANSACTION: "medicine_transaction",
  POST: "post",
  EVENT: "event",
  SURVEY: "survey",
  USER: "user",
  BARANGAY: "barangay",
};

const SYNC_ACTIONS = {
  CREATE: "create",
  UPDATE: "update",
  DELETE: "delete",
  BULK_SYNC: "bulk_sync",
};

const SYNC_STATUS = {
  SUCCESS: "success",
  FAILED: "failed",
  PARTIAL: "partial",
};

const syncLogSchema = new mongoose.Schema(
  {
    entityType: {
      type: String,
      enum: Object.values(SYNC_ENTITY_TYPES),
      required: [true, "Sync entity type is required."],
      index: true,
    },

    action: {
      type: String,
      enum: Object.values(SYNC_ACTIONS),
      required: [true, "Sync action is required."],
      index: true,
    },

    status: {
      type: String,
      enum: Object.values(SYNC_STATUS),
      required: [true, "Sync status is required."],
      index: true,
    },

    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      default: null,
      index: true,
    },

    barangay: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Barangay",
      default: null,
      index: true,
    },

    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Sync user is required."],
      index: true,
    },

    deviceId: {
      type: String,
      trim: true,
      maxlength: [150, "Device ID cannot exceed 150 characters."],
      default: "",
      index: true,
    },

    clientGeneratedId: {
      type: String,
      trim: true,
      maxlength: [150, "Client generated ID cannot exceed 150 characters."],
      default: "",
      index: true,
    },

    serverRecordId: {
      type: mongoose.Schema.Types.ObjectId,
      default: null,
      index: true,
    },

    totalRecords: {
      type: Number,
      min: [0, "Total records cannot be negative."],
      default: 0,
    },

    successCount: {
      type: Number,
      min: [0, "Success count cannot be negative."],
      default: 0,
    },

    failedCount: {
      type: Number,
      min: [0, "Failed count cannot be negative."],
      default: 0,
    },

    requestPayload: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },

    responsePayload: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },

    errorMessage: {
      type: String,
      trim: true,
      maxlength: [1000, "Error message cannot exceed 1000 characters."],
      default: "",
    },

    errorCode: {
      type: String,
      trim: true,
      maxlength: [80, "Error code cannot exceed 80 characters."],
      default: "",
    },

    startedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },

    completedAt: {
      type: Date,
      default: null,
    },

    durationMs: {
      type: Number,
      min: [0, "Duration cannot be negative."],
      default: 0,
    },

    appVersion: {
      type: String,
      trim: true,
      maxlength: [50, "App version cannot exceed 50 characters."],
      default: "",
    },

    platform: {
      type: String,
      trim: true,
      lowercase: true,
      maxlength: [50, "Platform cannot exceed 50 characters."],
      default: "android",
    },

    ipAddress: {
      type: String,
      trim: true,
      maxlength: [80, "IP address cannot exceed 80 characters."],
      default: "",
    },
  },
  {
    timestamps: true,
  }
);

syncLogSchema.index({
  user: 1,
  startedAt: -1,
});

syncLogSchema.index({
  rhu: 1,
  barangay: 1,
  startedAt: -1,
});

syncLogSchema.index({
  entityType: 1,
  status: 1,
  startedAt: -1,
});

syncLogSchema.index({
  deviceId: 1,
  clientGeneratedId: 1,
});

syncLogSchema.pre("save", function () {
  if (this.completedAt && this.startedAt) {
    this.durationMs = this.completedAt.getTime() - this.startedAt.getTime();
  }

  if (this.failedCount > 0 && this.successCount > 0) {
    this.status = SYNC_STATUS.PARTIAL;
  }

  if (this.failedCount > 0 && this.successCount === 0) {
    this.status = SYNC_STATUS.FAILED;
  }

  if (this.failedCount === 0 && this.successCount > 0) {
    this.status = SYNC_STATUS.SUCCESS;
  }
});

syncLogSchema.statics.entityTypes = SYNC_ENTITY_TYPES;
syncLogSchema.statics.actions = SYNC_ACTIONS;
syncLogSchema.statics.statuses = SYNC_STATUS;

module.exports = mongoose.model("SyncLog", syncLogSchema);