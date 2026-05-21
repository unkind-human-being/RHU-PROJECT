const mongoose = require("mongoose");

const EVENT_STATUS = {
  DRAFT: "draft",
  OPEN: "open",
  CLOSED: "closed",
  COMPLETED: "completed",
  CANCELLED: "cancelled",
};

const EVENT_TYPES = {
  HEALTH_PROGRAM: "health_program",
  VACCINATION: "vaccination",
  MEDICAL_MISSION: "medical_mission",
  DEWORMING: "deworming",
  FREE_CIRCUMCISION: "free_circumcision",
  COMMUNITY_MEETING: "community_meeting",
  OTHER: "other",
};

const AUDIENCE_SCOPE = {
  PUBLIC: "public",
  RHU_ONLY: "rhu_only",
  BARANGAY_ONLY: "barangay_only",
};

const eventSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: [true, "Event title is required."],
      trim: true,
      maxlength: [180, "Event title cannot exceed 180 characters."],
      index: true,
    },

    description: {
      type: String,
      required: [true, "Event description is required."],
      trim: true,
      maxlength: [5000, "Event description cannot exceed 5000 characters."],
    },

    type: {
      type: String,
      enum: Object.values(EVENT_TYPES),
      default: EVENT_TYPES.OTHER,
      index: true,
    },

    status: {
      type: String,
      enum: Object.values(EVENT_STATUS),
      default: EVENT_STATUS.DRAFT,
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
      required: [true, "Event must belong to an RHU."],
      index: true,
    },

    barangay: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Barangay",
      default: null,
      index: true,
    },

    locationName: {
      type: String,
      required: [true, "Event location is required."],
      trim: true,
      maxlength: [255, "Location name cannot exceed 255 characters."],
    },

    address: {
      type: String,
      trim: true,
      maxlength: [255, "Address cannot exceed 255 characters."],
      default: "",
    },

    startDate: {
      type: Date,
      required: [true, "Start date is required."],
      index: true,
    },

    endDate: {
      type: Date,
      required: [true, "End date is required."],
      index: true,
    },

    registrationRequired: {
      type: Boolean,
      default: false,
      index: true,
    },

    registrationDeadline: {
      type: Date,
      default: null,
      index: true,
    },

    maxParticipants: {
      type: Number,
      min: [0, "Maximum participants cannot be negative."],
      default: 0,
    },

    registeredCount: {
      type: Number,
      min: [0, "Registered count cannot be negative."],
      default: 0,
    },

    registeredUsers: [
      {
        user: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
          required: true,
        },
        fullName: {
          type: String,
          trim: true,
          maxlength: [120, "Full name cannot exceed 120 characters."],
        },
        email: {
          type: String,
          trim: true,
          lowercase: true,
        },
        phoneNumber: {
          type: String,
          trim: true,
          maxlength: [30, "Phone number cannot exceed 30 characters."],
          default: "",
        },
        registeredAt: {
          type: Date,
          default: Date.now,
        },
        status: {
          type: String,
          enum: ["registered", "cancelled", "attended", "no_show"],
          default: "registered",
        },
      },
    ],

    requirements: [
      {
        type: String,
        trim: true,
        maxlength: [180, "Requirement cannot exceed 180 characters."],
      },
    ],

    imageUrl: {
      type: String,
      trim: true,
      default: "",
    },

    contactPerson: {
      type: String,
      trim: true,
      maxlength: [120, "Contact person cannot exceed 120 characters."],
      default: "",
    },

    contactNumber: {
      type: String,
      trim: true,
      maxlength: [30, "Contact number cannot exceed 30 characters."],
      default: "",
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Event creator is required."],
      index: true,
    },

    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    publishedAt: {
      type: Date,
      default: null,
      index: true,
    },

    cancelledAt: {
      type: Date,
      default: null,
    },

    cancellationReason: {
      type: String,
      trim: true,
      maxlength: [500, "Cancellation reason cannot exceed 500 characters."],
      default: "",
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

eventSchema.index({
  status: 1,
  audienceScope: 1,
  startDate: 1,
});

eventSchema.index({
  rhu: 1,
  status: 1,
  startDate: 1,
});

eventSchema.index({
  rhu: 1,
  barangay: 1,
  status: 1,
  startDate: 1,
});

eventSchema.index({
  title: "text",
  description: "text",
  locationName: "text",
});

eventSchema.pre("validate", function () {
  if (this.startDate && this.endDate && this.endDate < this.startDate) {
    throw new Error("End date cannot be earlier than start date.");
  }

  if (
    this.registrationDeadline &&
    this.startDate &&
    this.registrationDeadline > this.startDate
  ) {
    throw new Error("Registration deadline cannot be after the event start date.");
  }

  if (
    this.maxParticipants > 0 &&
    this.registeredCount > this.maxParticipants
  ) {
    throw new Error("Registered count cannot exceed maximum participants.");
  }
});

eventSchema.pre("save", function () {
  if (this.status === EVENT_STATUS.OPEN && !this.publishedAt) {
    this.publishedAt = new Date();
  }

  if (this.status === EVENT_STATUS.CANCELLED && !this.cancelledAt) {
    this.cancelledAt = new Date();
  }

  this.registeredCount = this.registeredUsers.filter(
    (entry) => entry.status === "registered" || entry.status === "attended"
  ).length;
});

eventSchema.methods.canAcceptRegistration = function () {
  const now = new Date();

  if (!this.registrationRequired) {
    return false;
  }

  if (this.status !== EVENT_STATUS.OPEN) {
    return false;
  }

  if (this.registrationDeadline && now > this.registrationDeadline) {
    return false;
  }

  if (this.maxParticipants > 0 && this.registeredCount >= this.maxParticipants) {
    return false;
  }

  return true;
};

eventSchema.statics.eventStatuses = EVENT_STATUS;
eventSchema.statics.eventTypes = EVENT_TYPES;
eventSchema.statics.audienceScopes = AUDIENCE_SCOPE;

module.exports = mongoose.model("Event", eventSchema);