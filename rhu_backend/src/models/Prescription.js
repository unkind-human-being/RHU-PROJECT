const mongoose = require("mongoose");
const crypto = require("crypto");

const PRESCRIPTION_STATUS = {
  ISSUED: "issued",
  CLAIMED: "claimed",
  CANCELLED: "cancelled",
  EXPIRED: "expired",
};

const prescriptionMedicineSchema = new mongoose.Schema(
  {
    medicine: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Medicine",
      default: null,
    },

    medicineName: {
      type: String,
      required: [true, "Medicine name is required."],
      trim: true,
      maxlength: [160, "Medicine name cannot exceed 160 characters."],
    },

    genericName: {
      type: String,
      trim: true,
      maxlength: [160, "Generic name cannot exceed 160 characters."],
      default: "",
    },

    strength: {
      type: String,
      trim: true,
      maxlength: [80, "Strength cannot exceed 80 characters."],
      default: "",
    },

    dosageForm: {
      type: String,
      trim: true,
      maxlength: [80, "Dosage form cannot exceed 80 characters."],
      default: "",
    },

    quantity: {
      type: Number,
      required: [true, "Quantity is required."],
      min: [1, "Quantity must be at least 1."],
    },

    unit: {
      type: String,
      trim: true,
      maxlength: [40, "Unit cannot exceed 40 characters."],
      default: "pcs",
    },

    instructions: {
      type: String,
      trim: true,
      maxlength: [500, "Instructions cannot exceed 500 characters."],
      default: "",
    },
  },
  {
    _id: false,
  }
);

const prescriptionSchema = new mongoose.Schema(
  {
    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: [true, "RHU is required."],
      index: true,
    },

    appointment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Appointment",
      default: null,
      index: true,
    },

    patientUser: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
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
      default: null,
    },

    patientSex: {
      type: String,
      enum: ["male", "female", "prefer_not_to_say", ""],
      default: "",
    },

    contactNumber: {
      type: String,
      trim: true,
      maxlength: [30, "Contact number cannot exceed 30 characters."],
      default: "",
    },

    diagnosis: {
      type: String,
      trim: true,
      maxlength: [1000, "Diagnosis cannot exceed 1000 characters."],
      default: "",
    },

    doctorName: {
      type: String,
      trim: true,
      maxlength: [160, "Doctor name cannot exceed 160 characters."],
      default: "DR. Alnidzfar-nadz D. Jericho",
    },

    prescribedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Prescribing RHU admin is required."],
      index: true,
    },

    medicines: {
      type: [prescriptionMedicineSchema],
      validate: {
        validator(value) {
          return Array.isArray(value) && value.length > 0;
        },
        message: "At least one prescribed medicine is required.",
      },
    },

    qrToken: {
      type: String,
      unique: true,
      index: true,
    },

    qrPayload: {
      type: String,
      trim: true,
      default: "",
    },

    status: {
      type: String,
      enum: Object.values(PRESCRIPTION_STATUS),
      default: PRESCRIPTION_STATUS.ISSUED,
      index: true,
    },

    issuedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },

    expiresAt: {
      type: Date,
      required: [true, "QR expiration date is required."],
      index: true,
    },

    claimedAt: {
      type: Date,
      default: null,
    },

    claimedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    pharmacyName: {
      type: String,
      trim: true,
      maxlength: [160, "Pharmacy name cannot exceed 160 characters."],
      default: "",
    },

    pharmacyLocation: {
      type: String,
      trim: true,
      maxlength: [240, "Pharmacy location cannot exceed 240 characters."],
      default: "",
    },

    claimRemarks: {
      type: String,
      trim: true,
      maxlength: [1000, "Claim remarks cannot exceed 1000 characters."],
      default: "",
    },
  },
  {
    timestamps: true,
  }
);

prescriptionSchema.virtual("patientFullName").get(function () {
  const parts = [
    this.patientFirstName,
    this.patientMiddleInitial,
    this.patientLastName,
  ].filter(Boolean);

  return parts.join(" ");
});

prescriptionSchema.pre("validate", function () {
  if (!this.qrToken) {
    this.qrToken = crypto.randomBytes(32).toString("hex");
  }

  if (!this.qrPayload) {
    this.qrPayload = JSON.stringify({
      type: "rhu_prescription_qr",
      token: this.qrToken,
    });
  }
});

prescriptionSchema.methods.isExpiredNow = function () {
  return this.expiresAt && new Date(this.expiresAt).getTime() < Date.now();
};

prescriptionSchema.methods.toSafeObject = function () {
  const prescription = this.toObject({
    virtuals: true,
  });

  delete prescription.__v;

  return prescription;
};

prescriptionSchema.statics.statuses = PRESCRIPTION_STATUS;

module.exports = mongoose.model("Prescription", prescriptionSchema);