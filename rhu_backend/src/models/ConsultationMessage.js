const mongoose = require("mongoose");

const CONSULTATION_MESSAGE_TYPES = {
  TEXT: "text",
  PRESCRIPTION_QR: "prescription_qr",
  VIDEO_CALL: "video_call",
  SYSTEM: "system",
};

const consultationMessageSchema = new mongoose.Schema(
  {
    appointment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Appointment",
      required: [true, "Appointment is required."],
      index: true,
    },

    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: [true, "RHU is required."],
      index: true,
    },

    sentBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Sender is required."],
      index: true,
    },

    receiver: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Receiver is required."],
      index: true,
    },

    messageType: {
      type: String,
      enum: Object.values(CONSULTATION_MESSAGE_TYPES),
      default: CONSULTATION_MESSAGE_TYPES.TEXT,
      index: true,
    },

    body: {
      type: String,
      trim: true,
      maxlength: [3000, "Message cannot exceed 3000 characters."],
      default: "",
    },

    prescription: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Prescription",
      default: null,
      index: true,
    },

    prescriptionQrPayload: {
      type: String,
      trim: true,
      default: "",
    },

    videoChannelName: {
      type: String,
      trim: true,
      maxlength: [200, "Video channel name cannot exceed 200 characters."],
      default: "",
      index: true,
    },

    sentAt: {
      type: Date,
      default: Date.now,
      index: true,
    },

    readAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

consultationMessageSchema.index({ appointment: 1, sentAt: 1 });
consultationMessageSchema.index({ receiver: 1, readAt: 1 });

consultationMessageSchema.methods.toSafeObject = function () {
  const message = this.toObject();

  delete message.__v;

  return message;
};

consultationMessageSchema.statics.types = CONSULTATION_MESSAGE_TYPES;

module.exports = mongoose.model(
  "ConsultationMessage",
  consultationMessageSchema
);