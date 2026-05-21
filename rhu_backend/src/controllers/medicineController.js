const mongoose = require("mongoose");
const Medicine = require("../models/Medicine");
const MedicineTransaction = require("../models/MedicineTransaction");
const RHU = require("../models/RHU");
const Barangay = require("../models/Barangay");
const { asyncHandler } = require("../middleware/errorMiddleware");
const { USER_ROLES, TRANSACTION_TYPES } = require("../utils/constants");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);
const getUserBarangayId = (req) => getIdString(req.user?.barangay);

const checkMedicineAccess = (req, medicine) => {
  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  const medicineRhuId = getIdString(medicine.rhu);
  const medicineBarangayId = getIdString(medicine.barangay);

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === medicineRhuId) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access medicines under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (
      getUserRhuId(req) === medicineRhuId &&
      getUserBarangayId(req) === medicineBarangayId
    ) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access medicines under your assigned barangay.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to access medicine records.",
  };
};

const checkMedicineViewAccess = (req, medicine) => {
  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  const medicineRhuId = getIdString(medicine.rhu);

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === medicineRhuId) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only view medicines under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (getUserRhuId(req) === medicineRhuId) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only view medicines under your assigned RHU.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to view medicine records.",
  };
};



const buildMedicineFilter = (req) => {
    const filter = {
      isActive: true,
    };

    const viewScope = req.query.viewScope;

    if (req.user.role === USER_ROLES.RHU_ADMIN) {
      filter.rhu = getUserRhuId(req);

      if (req.query.barangay) {
        filter.barangay = req.query.barangay;
      }
    }

    if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
      filter.rhu = getUserRhuId(req);

      if (viewScope === "rhu") {
        if (req.query.barangay) {
          filter.barangay = req.query.barangay;
        }
      } else {
        filter.barangay = getUserBarangayId(req);
      }
    }

    if (req.user.role === USER_ROLES.IPHO_ADMIN) {
      if (req.query.rhu) {
        filter.rhu = req.query.rhu;
      }

      if (req.query.barangay) {
        filter.barangay = req.query.barangay;
      }
    }

    if (req.query.stockStatus) {
      filter.stockStatus = req.query.stockStatus;
    }

    if (req.query.expiringBefore) {
      filter.expirationDate = {
        $lte: new Date(req.query.expiringBefore),
      };
    }

    if (req.query.search) {
      const searchRegex = new RegExp(req.query.search.trim(), "i");

      filter.$or = [
        { name: searchRegex },
        { genericName: searchRegex },
        { brandName: searchRegex },
        { batchNumber: searchRegex },
        { category: searchRegex },
      ];
    }

    return filter;
  };

const validateRhuAndBarangay = async ({ rhu, barangay }) => {
  if (!rhu || !barangay) {
    throw new Error("RHU and barangay are required.");
  }

  const existingRHU = await RHU.findById(rhu);

  if (!existingRHU || !existingRHU.isActive) {
    throw new Error("Selected RHU does not exist or is inactive.");
  }

  const existingBarangay = await Barangay.findById(barangay);

  if (!existingBarangay || !existingBarangay.isActive) {
    throw new Error("Selected barangay does not exist or is inactive.");
  }

  if (existingBarangay.rhu.toString() !== rhu.toString()) {
    throw new Error("Selected barangay does not belong to the selected RHU.");
  }

  return {
    rhu: existingRHU,
    barangay: existingBarangay,
  };
};

const checkLocationAccess = (req, rhu, barangay) => {
  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === rhu.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only manage medicines under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (
      getUserRhuId(req) === rhu.toString() &&
      getUserBarangayId(req) === barangay.toString()
    ) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only manage medicines under your assigned barangay.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to manage medicine records.",
  };
};

const getMedicines = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = buildMedicineFilter(req);

  const [medicines, total] = await Promise.all([
    Medicine.find(filter)
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .populate("createdBy", "fullName email role")
      .sort({ updatedAt: -1 })
      .skip(skip)
      .limit(limit),
    Medicine.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Medicines fetched successfully.",
    count: medicines.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: medicines,
  });
});

const getMedicineById = asyncHandler(async (req, res) => {
  const medicine = await Medicine.findById(req.params.id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role")
    .populate("updatedBy", "fullName email role");

  if (!medicine || !medicine.isActive) {
    return res.status(404).json({
      success: false,
      message: "Medicine not found.",
    });
  }

  const access = checkMedicineViewAccess(req, {
    ...medicine.toObject(),
    rhu: medicine.rhu._id,
    barangay: medicine.barangay._id,
  });

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  return res.status(200).json({
    success: true,
    message: "Medicine fetched successfully.",
    data: medicine,
  });
});

const createMedicine = asyncHandler(async (req, res) => {
  const {
    name,
    genericName,
    brandName,
    dosageForm,
    strength,
    unit,
    category,
    rhu,
    barangay,
    currentStock,
    minimumStockLevel,
    maximumStockLevel,
    batchNumber,
    expirationDate,
    supplier,
    remarks,
  } = req.body;

  try {
    await validateRhuAndBarangay({ rhu, barangay });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }

  const access = checkLocationAccess(req, rhu, barangay);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const medicine = await Medicine.create({
    name,
    genericName,
    brandName,
    dosageForm,
    strength,
    unit,
    category,
    rhu,
    barangay,
    currentStock: currentStock || 0,
    minimumStockLevel,
    maximumStockLevel,
    batchNumber,
    expirationDate,
    supplier,
    remarks,
    createdBy: req.userId,
  });

  const createdMedicine = await Medicine.findById(medicine._id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role");

  return res.status(201).json({
    success: true,
    message: "Medicine created successfully.",
    data: createdMedicine,
  });
});

const updateMedicine = asyncHandler(async (req, res) => {
  const medicine = await Medicine.findById(req.params.id);

  if (!medicine || !medicine.isActive) {
    return res.status(404).json({
      success: false,
      message: "Medicine not found.",
    });
  }

  const access = checkMedicineAccess(req, medicine);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const allowedUpdates = [
    "name",
    "genericName",
    "brandName",
    "dosageForm",
    "strength",
    "unit",
    "category",
    "minimumStockLevel",
    "maximumStockLevel",
    "batchNumber",
    "expirationDate",
    "supplier",
    "remarks",
    "isActive",
  ];

  const updates = {};

  for (const field of allowedUpdates) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      updates[field] = req.body[field];
    }
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    delete updates.isActive;
  }

  updates.updatedBy = req.userId;

  const updatedMedicine = await Medicine.findByIdAndUpdate(
    req.params.id,
    updates,
    {
      new: true,
      runValidators: true,
    }
  )
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role")
    .populate("updatedBy", "fullName email role");

  return res.status(200).json({
    success: true,
    message: "Medicine updated successfully.",
    data: updatedMedicine,
  });
});

const deactivateMedicine = asyncHandler(async (req, res) => {
  const medicine = await Medicine.findById(req.params.id);

  if (!medicine) {
    return res.status(404).json({
      success: false,
      message: "Medicine not found.",
    });
  }

  const access = checkMedicineAccess(req, medicine);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  medicine.isActive = false;
  medicine.updatedBy = req.userId;
  await medicine.save();

  return res.status(200).json({
    success: true,
    message: "Medicine deactivated successfully.",
  });
});

const recordMedicineTransaction = asyncHandler(async (req, res) => {
  const {
    medicine: medicineId,
    transactionType,
    quantity,
    reason,
    remarks,
    patientReference,
    source,
    clientGeneratedId,
    deviceId,
    offlineCreatedAt,
  } = req.body;

  if (!medicineId || !transactionType || quantity === undefined || quantity === null) {
    return res.status(400).json({
      success: false,
      message: "Medicine, transaction type, and quantity are required.",
    });
  }

  if (!Object.values(TRANSACTION_TYPES).includes(transactionType)) {
    return res.status(400).json({
      success: false,
      message: "Invalid transaction type.",
    });
  }

  if (Number(quantity) < 0) {
    return res.status(400).json({
      success: false,
      message: "Quantity cannot be negative.",
    });
  }

  if (clientGeneratedId) {
    const duplicateTransaction = await MedicineTransaction.findOne({
      recordedBy: req.userId,
      clientGeneratedId,
    });

    if (duplicateTransaction) {
      return res.status(200).json({
        success: true,
        message: "Transaction already synced.",
        data: duplicateTransaction,
        duplicate: true,
      });
    }
  }

  const session = await mongoose.startSession();

  try {
    let savedTransaction;
    let updatedMedicine;

    await session.withTransaction(async () => {
      const medicine = await Medicine.findById(medicineId).session(session);

      if (!medicine || !medicine.isActive) {
        throw new Error("Medicine not found.");
      }

      const access = checkMedicineAccess(req, medicine);

      if (!access.allowed) {
        const error = new Error(access.message);
        error.statusCode = 403;
        throw error;
      }

      const previousStock = medicine.currentStock;

      if (transactionType === TRANSACTION_TYPES.RECEIVED) {
        medicine.increaseStock(Number(quantity));
      }

      if (transactionType === TRANSACTION_TYPES.DISPENSED) {
        medicine.decreaseStock(Number(quantity));
      }

      if (transactionType === TRANSACTION_TYPES.ADJUSTED) {
        medicine.adjustStock(Number(quantity));
      }

      medicine.updatedBy = req.userId;
      await medicine.save({ session });

      const transaction = new MedicineTransaction({
        medicine: medicine._id,
        rhu: medicine.rhu,
        barangay: medicine.barangay,
        transactionType,
        quantity: Number(quantity),
        previousStock,
        newStock: medicine.currentStock,
        batchNumber: medicine.batchNumber,
        expirationDate: medicine.expirationDate,
        reason,
        remarks,
        patientReference,
        source,
        recordedBy: req.userId,
        clientGeneratedId,
        deviceId,
        offlineCreatedAt,
        syncedAt: new Date(),
        syncStatus: "synced",
      });

      savedTransaction = await transaction.save({ session });
      updatedMedicine = medicine;
    });

    await session.endSession();

    const populatedTransaction = await MedicineTransaction.findById(savedTransaction._id)
      .populate("medicine", "name genericName brandName unit currentStock stockStatus")
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .populate("recordedBy", "fullName email role");

    return res.status(201).json({
      success: true,
      message: "Medicine transaction recorded successfully.",
      data: {
        transaction: populatedTransaction,
        medicine: updatedMedicine,
      },
    });
  } catch (error) {
    await session.endSession();

    return res.status(error.statusCode || 400).json({
      success: false,
      message: error.message,
    });
  }
});

const getMedicineTransactions = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = {
    isDeleted: false,
  };

  if (req.query.medicine) {
    filter.medicine = req.query.medicine;
  }

  if (req.query.transactionType) {
    filter.transactionType = req.query.transactionType;
  }

  if (req.query.startDate || req.query.endDate) {
    filter.transactionDate = {};

    if (req.query.startDate) {
      filter.transactionDate.$gte = new Date(req.query.startDate);
    }

    if (req.query.endDate) {
      filter.transactionDate.$lte = new Date(req.query.endDate);
    }
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    filter.rhu = getUserRhuId(req);
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    filter.rhu = getUserRhuId(req);

    if (req.query.barangay) {
      filter.barangay = req.query.barangay;
    }
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    if (req.query.rhu) {
      filter.rhu = req.query.rhu;
    }

    if (req.query.barangay) {
      filter.barangay = req.query.barangay;
    }
  }

  const [transactions, total] = await Promise.all([
    MedicineTransaction.find(filter)
      .populate("medicine", "name genericName brandName unit currentStock stockStatus")
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .populate("recordedBy", "fullName email role")
      .sort({ transactionDate: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit),
    MedicineTransaction.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Medicine transactions fetched successfully.",
    count: transactions.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: transactions,
  });
});

const getMedicineStockSummary = asyncHandler(async (req, res) => {
  const filter = buildMedicineFilter(req);

  const [
    totalMedicines,
    inStock,
    lowStock,
    outOfStock,
    expired,
    totalStockResult,
  ] = await Promise.all([
    Medicine.countDocuments(filter),
    Medicine.countDocuments({ ...filter, stockStatus: "in_stock" }),
    Medicine.countDocuments({ ...filter, stockStatus: "low_stock" }),
    Medicine.countDocuments({ ...filter, stockStatus: "out_of_stock" }),
    Medicine.countDocuments({ ...filter, stockStatus: "expired" }),
    Medicine.aggregate([
      {
        $match: filter,
      },
      {
        $group: {
          _id: null,
          totalStock: {
            $sum: "$currentStock",
          },
        },
      },
    ]),
  ]);

  return res.status(200).json({
    success: true,
    message: "Medicine stock summary fetched successfully.",
    data: {
      totalMedicines,
      totalStock: totalStockResult[0]?.totalStock || 0,
      inStock,
      lowStock,
      outOfStock,
      expired,
    },
  });
});

module.exports = {
  getMedicines,
  getMedicineById,
  createMedicine,
  updateMedicine,
  deactivateMedicine,
  recordMedicineTransaction,
  getMedicineTransactions,
  getMedicineStockSummary,
};