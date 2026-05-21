const mongoose = require("mongoose");

const VIDEO_CALL_STATUS = Object.freeze({
  ACTIVE: "active",
  ENDED: "ended",
  MISSED: "missed",
});

const videoCallParticipantSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    role: {
      type: String,
      trim: true,
      default: "",
    },

    uid: {
      type: Number,
      default: 0,
    },

    joinedAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    _id: false,
  }
);

const videoCallLogSchema = new mongoose.Schema(
  {
    appointment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Appointment",
      required: true,
      index: true,
    },

    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: true,
      index: true,
    },

    channelName: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },

    startedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    startedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },

    participants: {
      type: [videoCallParticipantSchema],
      default: [],
    },

    endedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    endedAt: {
      type: Date,
      default: null,
    },

    durationSeconds: {
      type: Number,
      default: 0,
    },

    status: {
      type: String,
      enum: Object.values(VIDEO_CALL_STATUS),
      default: VIDEO_CALL_STATUS.ACTIVE,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

videoCallLogSchema.index({ appointment: 1, startedAt: -1 });
videoCallLogSchema.index({ channelName: 1, status: 1 });

videoCallLogSchema.methods.toSafeObject = function () {
  const log = this.toObject();

  delete log.__v;

  return log;
};

videoCallLogSchema.statics.statuses = VIDEO_CALL_STATUS;

module.exports = mongoose.model("VideoCallLog", videoCallLogSchema);