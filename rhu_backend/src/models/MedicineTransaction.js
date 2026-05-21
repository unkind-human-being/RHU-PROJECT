const mongoose = require("mongoose");

const TRANSACTION_TYPES = {
  RECEIVED: "received",
  DISPENSED: "dispensed",
  ADJUSTED: "adjusted",
};

const SYNC_STATUS = {
  SYNCED: "synced",
  PENDING: "pending",
  FAILED: "failed",
};

const medicineTransactionSchema = new mongoose.Schema(
  {
    medicine: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Medicine",
      required: [true, "Medicine reference is required."],
      index: true,
    },

    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: [true, "RHU reference is required."],
      index: true,
    },

    barangay: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Barangay",
      required: [true, "Barangay reference is required."],
      index: true,
    },

    transactionType: {
      type: String,
      enum: Object.values(TRANSACTION_TYPES),
      required: [true, "Transaction type is required."],
      index: true,
    },

    quantity: {
      type: Number,
      required: [true, "Quantity is required."],
      min: [0, "Quantity cannot be negative."],
    },

    previousStock: {
      type: Number,
      required: [true, "Previous stock is required."],
      min: [0, "Previous stock cannot be negative."],
    },

    newStock: {
      type: Number,
      required: [true, "New stock is required."],
      min: [0, "New stock cannot be negative."],
    },

    batchNumber: {
      type: String,
      trim: true,
      maxlength: [100, "Batch number cannot exceed 100 characters."],
      default: "",
      index: true,
    },

    expirationDate: {
      type: Date,
      default: null,
      index: true,
    },

    reason: {
      type: String,
      trim: true,
      maxlength: [255, "Reason cannot exceed 255 characters."],
      default: "",
    },

    remarks: {
      type: String,
      trim: true,
      maxlength: [500, "Remarks cannot exceed 500 characters."],
      default: "",
    },

    patientReference: {
      type: String,
      trim: true,
      maxlength: [120, "Patient reference cannot exceed 120 characters."],
      default: "",
    },

    source: {
      type: String,
      trim: true,
      maxlength: [150, "Source cannot exceed 150 characters."],
      default: "",
    },

    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Recorded by user is required."],
      index: true,
    },

    approvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    transactionDate: {
      type: Date,
      default: Date.now,
      index: true,
    },

    clientGeneratedId: {
      type: String,
      trim: true,
      maxlength: [150, "Client generated ID cannot exceed 150 characters."],
      default: "",
      index: true,
    },

    deviceId: {
      type: String,
      trim: true,
      maxlength: [150, "Device ID cannot exceed 150 characters."],
      default: "",
      index: true,
    },

    offlineCreatedAt: {
      type: Date,
      default: null,
    },

    syncedAt: {
      type: Date,
      default: Date.now,
    },

    syncStatus: {
      type: String,
      enum: Object.values(SYNC_STATUS),
      default: SYNC_STATUS.SYNCED,
      index: true,
    },

    syncError: {
      type: String,
      trim: true,
      maxlength: [500, "Sync error cannot exceed 500 characters."],
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

medicineTransactionSchema.index({
  rhu: 1,
  barangay: 1,
  transactionDate: -1,
});

medicineTransactionSchema.index({
  medicine: 1,
  transactionDate: -1,
});

medicineTransactionSchema.index({
  recordedBy: 1,
  transactionDate: -1,
});

medicineTransactionSchema.index({
  rhu: 1,
  barangay: 1,
  transactionType: 1,
});

medicineTransactionSchema.index(
  {
    recordedBy: 1,
    clientGeneratedId: 1,
  },
  {
    unique: true,
    partialFilterExpression: {
      clientGeneratedId: { $type: "string", $ne: "" },
    },
  }
);

medicineTransactionSchema.pre("validate", function () {
  if (this.transactionType === TRANSACTION_TYPES.RECEIVED) {
    this.newStock = this.previousStock + this.quantity;
  }

  if (this.transactionType === TRANSACTION_TYPES.DISPENSED) {
    if (this.quantity > this.previousStock) {
      throw new Error("Dispensed quantity cannot be greater than current stock.");
    }

    this.newStock = this.previousStock - this.quantity;
  }

  if (this.transactionType === TRANSACTION_TYPES.ADJUSTED) {
    this.newStock = this.quantity;
  }

  if (this.offlineCreatedAt && this.offlineCreatedAt > new Date()) {
    throw new Error("Offline created date cannot be in the future.");
  }
});

medicineTransactionSchema.statics.transactionTypes = TRANSACTION_TYPES;
medicineTransactionSchema.statics.syncStatuses = SYNC_STATUS;

module.exports = mongoose.model(
  "MedicineTransaction",
  medicineTransactionSchema
);