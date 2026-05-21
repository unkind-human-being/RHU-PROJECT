const mongoose = require("mongoose");

const rhuSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "RHU name is required."],
      trim: true,
      unique: true,
      maxlength: [150, "RHU name cannot exceed 150 characters."],
    },

    code: {
      type: String,
      required: [true, "RHU code is required."],
      trim: true,
      lowercase: true,
      unique: true,
      index: true,
      match: [
        /^[a-z0-9_]+$/,
        "RHU code can only contain lowercase letters, numbers, and underscores.",
      ],
    },

    municipality: {
      type: String,
      required: [true, "Municipality is required."],
      trim: true,
      maxlength: [120, "Municipality cannot exceed 120 characters."],
    },

    province: {
      type: String,
      trim: true,
      default: "Tawi-Tawi",
      maxlength: [120, "Province cannot exceed 120 characters."],
    },

    barangayCount: {
      type: Number,
      required: [true, "Barangay count is required."],
      min: [0, "Barangay count cannot be negative."],
      default: 0,
    },

    address: {
      type: String,
      trim: true,
      maxlength: [255, "Address cannot exceed 255 characters."],
      default: "",
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
      default: "",
      match: [
        /^$|^\S+@\S+\.\S+$/,
        "Please provide a valid RHU email address.",
      ],
    },

    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

rhuSchema.index({ municipality: 1 });

module.exports = mongoose.model("RHU", rhuSchema);