const mongoose = require("mongoose");

const barangaySchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Barangay name is required."],
      trim: true,
      maxlength: [150, "Barangay name cannot exceed 150 characters."],
    },

    code: {
      type: String,
      required: [true, "Barangay code is required."],
      trim: true,
      lowercase: true,
      match: [
        /^[a-z0-9_]+$/,
        "Barangay code can only contain lowercase letters, numbers, and underscores.",
      ],
    },

    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: [true, "Barangay must belong to an RHU."],
      index: true,
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

    assignedHealthWorkers: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],

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

barangaySchema.index({ rhu: 1, code: 1 }, { unique: true });
barangaySchema.index({ rhu: 1, name: 1 }, { unique: true });
barangaySchema.index({ municipality: 1 });

barangaySchema.virtual("healthWorkerCount").get(function () {
  return this.assignedHealthWorkers ? this.assignedHealthWorkers.length : 0;
});

barangaySchema.set("toJSON", { virtuals: true });
barangaySchema.set("toObject", { virtuals: true });

module.exports = mongoose.model("Barangay", barangaySchema);