const mongoose = require("mongoose");

const appointmentSettingSchema = new mongoose.Schema(
  {
    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: [true, "RHU is required."],
      unique: true,
      index: true,
    },

    isAcceptingAppointments: {
      type: Boolean,
      default: true,
      index: true,
    },

    allowWalkIn: {
      type: Boolean,
      default: true,
    },

    allowOnline: {
      type: Boolean,
      default: true,
    },

    unavailableReason: {
      type: String,
      trim: true,
      maxlength: [500, "Unavailable reason cannot exceed 500 characters."],
      default: "",
    },

    walkInStartTime: {
      type: String,
      trim: true,
      default: "08:00",
    },

    walkInEndTime: {
      type: String,
      trim: true,
      default: "17:00",
    },

    onlineStartTime: {
      type: String,
      trim: true,
      default: "08:00",
    },

    onlineEndTime: {
      type: String,
      trim: true,
      default: "17:00",
    },

    monday: {
      type: Boolean,
      default: true,
    },

    tuesday: {
      type: Boolean,
      default: true,
    },

    wednesday: {
      type: Boolean,
      default: true,
    },

    thursday: {
      type: Boolean,
      default: true,
    },

    friday: {
      type: Boolean,
      default: true,
    },

    saturday: {
      type: Boolean,
      default: false,
    },

    sunday: {
      type: Boolean,
      default: false,
    },

    maxWalkInPerDay: {
      type: Number,
      min: [0, "Maximum walk-in appointments cannot be negative."],
      default: 50,
    },

    maxOnlinePerDay: {
      type: Number,
      min: [0, "Maximum online appointments cannot be negative."],
      default: 20,
    },

    instructionsForPatients: {
      type: String,
      trim: true,
      maxlength: [1500, "Instructions cannot exceed 1500 characters."],
      default:
        "Please wait for RHU approval. If accepted, your schedule and QR ticket will appear in your account.",
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

appointmentSettingSchema.methods.toSafeObject = function () {
  const setting = this.toObject();

  delete setting.__v;

  return setting;
};

module.exports = mongoose.model("AppointmentSetting", appointmentSettingSchema);