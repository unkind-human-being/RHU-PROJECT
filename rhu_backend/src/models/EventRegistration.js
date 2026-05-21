const mongoose = require("mongoose");

const EVENT_REGISTRATION_STATUS = {
  REGISTERED: "registered",
  CANCELLED: "cancelled",
  ATTENDED: "attended",
  NO_SHOW: "no_show",
};

const eventRegistrationSchema = new mongoose.Schema(
  {
    event: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Event",
      required: [true, "Event is required."],
      index: true,
    },

    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: [true, "RHU is required."],
      index: true,
    },

    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "User is required."],
      index: true,
    },

    attendeeName: {
      type: String,
      trim: true,
      required: [true, "Attendee name is required."],
      maxlength: [150, "Attendee name cannot exceed 150 characters."],
    },

    contactNumber: {
      type: String,
      trim: true,
      maxlength: [30, "Contact number cannot exceed 30 characters."],
      default: "",
    },

    email: {
      type: String,
      trim: true,
      lowercase: true,
      maxlength: [150, "Email cannot exceed 150 characters."],
      default: "",
    },

    notes: {
      type: String,
      trim: true,
      maxlength: [1000, "Notes cannot exceed 1000 characters."],
      default: "",
    },

    status: {
      type: String,
      enum: Object.values(EVENT_REGISTRATION_STATUS),
      default: EVENT_REGISTRATION_STATUS.REGISTERED,
      index: true,
    },

    registeredAt: {
      type: Date,
      default: Date.now,
      index: true,
    },

    checkedInAt: {
      type: Date,
      default: null,
    },

    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

eventRegistrationSchema.index(
  {
    event: 1,
    user: 1,
  },
  {
    unique: true,
  }
);

eventRegistrationSchema.methods.toSafeObject = function () {
  const registration = this.toObject();

  delete registration.__v;

  return registration;
};

eventRegistrationSchema.statics.statuses = EVENT_REGISTRATION_STATUS;

module.exports = mongoose.model("EventRegistration", eventRegistrationSchema);