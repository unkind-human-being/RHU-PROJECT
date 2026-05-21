const mongoose = require("mongoose");

const NOTIFICATION_TYPES = Object.freeze({
  APPOINTMENT_SUBMITTED: "appointment_submitted",
  APPOINTMENT_ACCEPTED: "appointment_accepted",
  APPOINTMENT_REJECTED: "appointment_rejected",
  WALK_IN_QR_GENERATED: "walk_in_qr_generated",
  PRESCRIPTION_QR_RECEIVED: "prescription_qr_received",
  PRESCRIPTION_CLAIMED: "prescription_claimed",
  EVENT_REGISTRATION_CONFIRMED: "event_registration_confirmed",
  EVENT_REGISTRATION_RECEIVED: "event_registration_received",
  SURVEY_SUBMITTED: "survey_submitted",
  SURVEY_RESPONSE_RECEIVED: "survey_response_received",
  PHARMACY_CLAIM_SYNCED: "pharmacy_claim_synced",
  PHARMACY_CLAIM_PENDING: "pharmacy_claim_pending",
  GENERAL: "general",
});

const notificationSchema = new mongoose.Schema(
  {
    recipient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Notification recipient is required."],
      index: true,
    },

    actor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    type: {
      type: String,
      enum: Object.values(NOTIFICATION_TYPES),
      default: NOTIFICATION_TYPES.GENERAL,
      index: true,
    },

    title: {
      type: String,
      required: [true, "Notification title is required."],
      trim: true,
      maxlength: [180, "Notification title cannot exceed 180 characters."],
    },

    body: {
      type: String,
      trim: true,
      maxlength: [1000, "Notification body cannot exceed 1000 characters."],
      default: "",
    },

    targetRoute: {
      type: String,
      trim: true,
      maxlength: [200, "Target route cannot exceed 200 characters."],
      default: "",
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

    appointment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Appointment",
      default: null,
      index: true,
    },

    prescription: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Prescription",
      default: null,
      index: true,
    },

    event: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Event",
      default: null,
      index: true,
    },

    survey: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Survey",
      default: null,
      index: true,
    },

    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },

    isRead: {
      type: Boolean,
      default: false,
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

notificationSchema.index({
  recipient: 1,
  isRead: 1,
  createdAt: -1,
});

notificationSchema.methods.markAsRead = function () {
  this.isRead = true;
  this.readAt = this.readAt || new Date();

  return this.save();
};

notificationSchema.methods.toSafeObject = function () {
  const notification = this.toObject();

  delete notification.__v;

  return notification;
};

notificationSchema.statics.types = NOTIFICATION_TYPES;

module.exports = mongoose.model("Notification", notificationSchema);