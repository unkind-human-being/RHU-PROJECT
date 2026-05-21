const mongoose = require("mongoose");
const crypto = require("crypto");

const APPOINTMENT_STATUS = {
  PENDING: "pending",
  ACCEPTED: "accepted",
  REJECTED: "rejected",
  CANCELLED: "cancelled",
  COMPLETED: "completed",
  EXPIRED: "expired",
};

const APPOINTMENT_TYPES = {
  WALK_IN: "walk_in",
  ONLINE: "online",
};

const APPOINTMENT_SERVICES = {
  MEDICAL_CONSULTATION: "medical_consultation",
  MATERNAL_CARE: "maternal_care",
  FAMILY_PLANNING: "family_planning",
  SCREENING_PREVENTION: "screening_prevention",
  DENTAL_SERVICES: "dental_services",
  IMMUNIZATION: "immunization",
};

const appointmentSchema = new mongoose.Schema(
  {
    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: [true, "RHU is required."],
      index: true,
    },

    requestedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Requesting user is required."],
      index: true,
    },

    serviceType: {
      type: String,
      enum: Object.values(APPOINTMENT_SERVICES),
      required: [true, "Service type is required."],
      index: true,
    },

    appointmentType: {
      type: String,
      enum: Object.values(APPOINTMENT_TYPES),
      required: [true, "Appointment type is required."],
      index: true,
    },

    patientLastName: {
      type: String,
      required: [true, "Patient last name is required."],
      trim: true,
      maxlength: [100, "Patient last name cannot exceed 100 characters."],
    },

    patientFirstName: {
      type: String,
      required: [true, "Patient first name is required."],
      trim: true,
      maxlength: [100, "Patient first name cannot exceed 100 characters."],
    },

    patientMiddleInitial: {
      type: String,
      trim: true,
      maxlength: [10, "Middle initial cannot exceed 10 characters."],
      default: "",
    },

    patientAge: {
      type: Number,
      min: [0, "Age cannot be negative."],
      max: [130, "Age is too high."],
      required: [true, "Patient age is required."],
    },

    patientSex: {
      type: String,
      enum: ["male", "female", "prefer_not_to_say"],
      required: [true, "Patient sex is required."],
    },

    religion: {
      type: String,
      enum: ["islam", "christianity", "other", "prefer_not_to_say"],
      default: "prefer_not_to_say",
    },

    civilStatus: {
      type: String,
      enum: ["single", "married", "widowed", "separated", "prefer_not_to_say"],
      default: "prefer_not_to_say",
    },

    contactNumber: {
      type: String,
      required: [true, "Contact number is required."],
      trim: true,
      maxlength: [30, "Contact number cannot exceed 30 characters."],
    },

    patientPhotoUrl: {
      type: String,
      trim: true,
      maxlength: [1000, "Patient photo URL cannot exceed 1000 characters."],
      default: "",
    },

    healthConcern: {
      type: String,
      required: [true, "Health concern is required."],
      trim: true,
      maxlength: [1000, "Health concern cannot exceed 1000 characters."],
    },

    symptomsDescription: {
      type: String,
      trim: true,
      maxlength: [2000, "Symptoms description cannot exceed 2000 characters."],
      default: "",
    },

    preferredDate: {
      type: Date,
      default: null,
    },

    preferredTime: {
      type: String,
      trim: true,
      maxlength: [40, "Preferred time cannot exceed 40 characters."],
      default: "",
    },

    confirmationChecked: {
      type: Boolean,
      required: [true, "Confirmation is required."],
      default: false,
    },

    status: {
      type: String,
      enum: Object.values(APPOINTMENT_STATUS),
      default: APPOINTMENT_STATUS.PENDING,
      index: true,
    },

    scheduledAt: {
      type: Date,
      default: null,
      index: true,
    },

    scheduledEndAt: {
      type: Date,
      default: null,
    },

    acceptedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    acceptedAt: {
      type: Date,
      default: null,
    },

    rejectedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    rejectedAt: {
      type: Date,
      default: null,
    },

    rejectionReason: {
      type: String,
      trim: true,
      maxlength: [1000, "Rejection reason cannot exceed 1000 characters."],
      default: "",
    },

    adminNotes: {
      type: String,
      trim: true,
      maxlength: [2000, "Admin notes cannot exceed 2000 characters."],
      default: "",
    },

    qrToken: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },

    qrPayload: {
      type: String,
      trim: true,
      default: "",
    },

    qrExpiresAt: {
      type: Date,
      default: null,
      index: true,
    },

    checkedInAt: {
      type: Date,
      default: null,
    },

    completedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    completedAt: {
      type: Date,
      default: null,
    },

    consultationDiagnosis: {
      type: String,
      trim: true,
      maxlength: [1500, "Consultation diagnosis cannot exceed 1500 characters."],
      default: "",
    },

    consultationNotes: {
      type: String,
      trim: true,
      maxlength: [3000, "Consultation notes cannot exceed 3000 characters."],
      default: "",
    },

    followUpInstructions: {
      type: String,
      trim: true,
      maxlength: [2500, "Follow-up instructions cannot exceed 2500 characters."],
      default: "",
    },

    followUpDate: {
      type: Date,
      default: null,
    },

    cancelledAt: {
      type: Date,
      default: null,
    },

    cancellationReason: {
      type: String,
      trim: true,
      maxlength: [1000, "Cancellation reason cannot exceed 1000 characters."],
      default: "",
    },
  },
  {
    timestamps: true,
  }
);

appointmentSchema.index({ rhu: 1, status: 1, scheduledAt: 1 });
appointmentSchema.index({ requestedBy: 1, status: 1 });
appointmentSchema.index({ completedBy: 1, completedAt: -1 });

appointmentSchema.virtual("patientFullName").get(function () {
  const parts = [
    this.patientFirstName,
    this.patientMiddleInitial,
    this.patientLastName,
  ].filter(Boolean);

  return parts.join(" ");
});

appointmentSchema.methods.ensureQrToken = function () {
  if (!this.qrToken) {
    this.qrToken = crypto.randomBytes(32).toString("hex");
  }

  return this.qrToken;
};

appointmentSchema.methods.isQrExpiredNow = function () {
  return this.qrExpiresAt && new Date(this.qrExpiresAt).getTime() < Date.now();
};

appointmentSchema.methods.toSafeObject = function () {
  const appointment = this.toObject({
    virtuals: true,
  });

  delete appointment.__v;

  return appointment;
};

appointmentSchema.statics.statuses = APPOINTMENT_STATUS;
appointmentSchema.statics.types = APPOINTMENT_TYPES;
appointmentSchema.statics.services = APPOINTMENT_SERVICES;

module.exports = mongoose.model("Appointment", appointmentSchema);