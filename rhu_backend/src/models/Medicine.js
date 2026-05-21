const mongoose = require("mongoose");

const STOCK_STATUS = {
  IN_STOCK: "in_stock",
  LOW_STOCK: "low_stock",
  OUT_OF_STOCK: "out_of_stock",
  EXPIRED: "expired",
};

const medicineSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Medicine name is required."],
      trim: true,
      maxlength: [150, "Medicine name cannot exceed 150 characters."],
      index: true,
    },

    genericName: {
      type: String,
      trim: true,
      maxlength: [150, "Generic name cannot exceed 150 characters."],
      default: "",
    },

    brandName: {
      type: String,
      trim: true,
      maxlength: [150, "Brand name cannot exceed 150 characters."],
      default: "",
    },

    dosageForm: {
      type: String,
      trim: true,
      maxlength: [80, "Dosage form cannot exceed 80 characters."],
      default: "",
    },

    strength: {
      type: String,
      trim: true,
      maxlength: [80, "Strength cannot exceed 80 characters."],
      default: "",
    },

    unit: {
      type: String,
      required: [true, "Medicine unit is required."],
      trim: true,
      lowercase: true,
      maxlength: [50, "Unit cannot exceed 50 characters."],
      default: "pcs",
    },

    category: {
      type: String,
      trim: true,
      maxlength: [100, "Category cannot exceed 100 characters."],
      default: "",
    },

    rhu: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "RHU",
      required: [true, "Medicine must belong to an RHU."],
      index: true,
    },

    barangay: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Barangay",
      required: [true, "Medicine must belong to a barangay."],
      index: true,
    },

    currentStock: {
      type: Number,
      required: [true, "Current stock is required."],
      min: [0, "Current stock cannot be negative."],
      default: 0,
      index: true,
    },

    minimumStockLevel: {
      type: Number,
      min: [0, "Minimum stock level cannot be negative."],
      default: 10,
    },

    maximumStockLevel: {
      type: Number,
      min: [0, "Maximum stock level cannot be negative."],
      default: 0,
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

    supplier: {
      type: String,
      trim: true,
      maxlength: [150, "Supplier cannot exceed 150 characters."],
      default: "",
    },

    remarks: {
      type: String,
      trim: true,
      maxlength: [500, "Remarks cannot exceed 500 characters."],
      default: "",
    },

    stockStatus: {
      type: String,
      enum: Object.values(STOCK_STATUS),
      default: STOCK_STATUS.OUT_OF_STOCK,
      index: true,
    },

    lastTransactionAt: {
      type: Date,
      default: null,
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Creator is required."],
    },

    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

medicineSchema.index({
  rhu: 1,
  barangay: 1,
  name: 1,
  batchNumber: 1,
  expirationDate: 1,
});

medicineSchema.index({
  rhu: 1,
  barangay: 1,
  stockStatus: 1,
});

medicineSchema.index({
  rhu: 1,
  barangay: 1,
  isActive: 1,
});

medicineSchema.pre("save", function () {
  const now = new Date();

  if (this.expirationDate && this.expirationDate < now) {
    this.stockStatus = STOCK_STATUS.EXPIRED;
  } else if (this.currentStock <= 0) {
    this.stockStatus = STOCK_STATUS.OUT_OF_STOCK;
  } else if (this.currentStock <= this.minimumStockLevel) {
    this.stockStatus = STOCK_STATUS.LOW_STOCK;
  } else {
    this.stockStatus = STOCK_STATUS.IN_STOCK;
  }
});

medicineSchema.methods.increaseStock = function (quantity) {
  if (quantity <= 0) {
    throw new Error("Quantity must be greater than zero.");
  }

  this.currentStock += quantity;
  this.lastTransactionAt = new Date();
};

medicineSchema.methods.decreaseStock = function (quantity) {
  if (quantity <= 0) {
    throw new Error("Quantity must be greater than zero.");
  }

  if (this.currentStock < quantity) {
    throw new Error("Not enough stock available.");
  }

  this.currentStock -= quantity;
  this.lastTransactionAt = new Date();
};

medicineSchema.methods.adjustStock = function (newQuantity) {
  if (newQuantity < 0) {
    throw new Error("Adjusted stock cannot be negative.");
  }

  this.currentStock = newQuantity;
  this.lastTransactionAt = new Date();
};

medicineSchema.statics.stockStatuses = STOCK_STATUS;

module.exports = mongoose.model("Medicine", medicineSchema);