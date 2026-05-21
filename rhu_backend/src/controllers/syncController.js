const mongoose = require("mongoose");
const Medicine = require("../models/Medicine");
const MedicineTransaction = require("../models/MedicineTransaction");
const SyncLog = require("../models/SyncLog");
const { asyncHandler } = require("../middleware/errorMiddleware");
const {
  USER_ROLES,
  TRANSACTION_TYPES,
  SYNC_ENTITY_TYPES,
  SYNC_ACTIONS,
  SYNC_LOG_STATUS,
} = require("../utils/constants");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);
const getUserBarangayId = (req) => getIdString(req.user?.barangay);

const checkMedicineAccess = (req, medicine) => {
  const medicineRhuId = getIdString(medicine.rhu);
  const medicineBarangayId = getIdString(medicine.barangay);

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === medicineRhuId) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only sync medicine records under your assigned RHU.",
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
      message: "You can only sync medicine records under your assigned barangay.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to sync medicine records.",
  };
};

const validateSyncItem = (item) => {
  if (!item.clientGeneratedId) {
    throw new Error("clientGeneratedId is required for offline sync.");
  }

  if (!item.medicine) {
    throw new Error("Medicine ID is required.");
  }

  if (!item.transactionType) {
    throw new Error("Transaction type is required.");
  }

  if (!Object.values(TRANSACTION_TYPES).includes(item.transactionType)) {
    throw new Error("Invalid transaction type.");
  }

  if (item.quantity === undefined || item.quantity === null) {
    throw new Error("Quantity is required.");
  }

  if (Number(item.quantity) < 0) {
    throw new Error("Quantity cannot be negative.");
  }
};

const applyTransactionToMedicine = (medicine, transactionType, quantity) => {
  const numericQuantity = Number(quantity);

  if (transactionType === TRANSACTION_TYPES.RECEIVED) {
    medicine.increaseStock(numericQuantity);
  }

  if (transactionType === TRANSACTION_TYPES.DISPENSED) {
    medicine.decreaseStock(numericQuantity);
  }

  if (transactionType === TRANSACTION_TYPES.ADJUSTED) {
    medicine.adjustStock(numericQuantity);
  }
};

const processMedicineTransactionSyncItem = async (req, item) => {
  validateSyncItem(item);

  const existingTransaction = await MedicineTransaction.findOne({
    recordedBy: req.userId,
    clientGeneratedId: item.clientGeneratedId,
  })
    .populate("medicine", "name genericName brandName unit currentStock stockStatus")
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("recordedBy", "fullName email role");

  if (existingTransaction) {
    return {
      success: true,
      duplicate: true,
      clientGeneratedId: item.clientGeneratedId,
      serverRecordId: existingTransaction._id,
      message: "Transaction already synced.",
      data: existingTransaction,
    };
  }

  const session = await mongoose.startSession();

  try {
    let savedTransaction;

    await session.withTransaction(async () => {
      const medicine = await Medicine.findById(item.medicine).session(session);

      if (!medicine || !medicine.isActive) {
        throw new Error("Medicine not found or inactive.");
      }

      const access = checkMedicineAccess(req, medicine);

      if (!access.allowed) {
        const accessError = new Error(access.message);
        accessError.statusCode = 403;
        throw accessError;
      }

      const previousStock = medicine.currentStock;

      applyTransactionToMedicine(
        medicine,
        item.transactionType,
        Number(item.quantity)
      );

      medicine.updatedBy = req.userId;
      await medicine.save({ session });

      const transaction = new MedicineTransaction({
        medicine: medicine._id,
        rhu: medicine.rhu,
        barangay: medicine.barangay,
        transactionType: item.transactionType,
        quantity: Number(item.quantity),
        previousStock,
        newStock: medicine.currentStock,
        batchNumber: medicine.batchNumber,
        expirationDate: medicine.expirationDate,
        reason: item.reason || "",
        remarks: item.remarks || "",
        patientReference: item.patientReference || "",
        source: item.source || "",
        recordedBy: req.userId,
        clientGeneratedId: item.clientGeneratedId,
        deviceId: item.deviceId || "",
        offlineCreatedAt: item.offlineCreatedAt || null,
        syncedAt: new Date(),
        syncStatus: "synced",
      });

      savedTransaction = await transaction.save({ session });
    });

    await session.endSession();

    const populatedTransaction = await MedicineTransaction.findById(
      savedTransaction._id
    )
      .populate("medicine", "name genericName brandName unit currentStock stockStatus")
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .populate("recordedBy", "fullName email role");

    return {
      success: true,
      duplicate: false,
      clientGeneratedId: item.clientGeneratedId,
      serverRecordId: populatedTransaction._id,
      message: "Transaction synced successfully.",
      data: populatedTransaction,
    };
  } catch (error) {
    await session.endSession();

    throw error;
  }
};

const syncMedicineTransactions = asyncHandler(async (req, res) => {
  const { transactions, deviceId, appVersion, platform } = req.body;

  if (!Array.isArray(transactions)) {
    return res.status(400).json({
      success: false,
      message: "transactions must be an array.",
    });
  }

  if (transactions.length === 0) {
    return res.status(400).json({
      success: false,
      message: "At least one transaction is required for sync.",
    });
  }

  if (transactions.length > 100) {
    return res.status(400).json({
      success: false,
      message: "You can sync a maximum of 100 transactions per request.",
    });
  }

  const startedAt = new Date();
  const results = [];
  let successCount = 0;
  let failedCount = 0;

  for (const item of transactions) {
    try {
      const result = await processMedicineTransactionSyncItem(req, {
        ...item,
        deviceId: item.deviceId || deviceId || "",
      });

      successCount += 1;
      results.push(result);
    } catch (error) {
      failedCount += 1;

      results.push({
        success: false,
        clientGeneratedId: item.clientGeneratedId || null,
        message: error.message,
      });
    }
  }

  const completedAt = new Date();

  let status = SYNC_LOG_STATUS.SUCCESS;

  if (successCount > 0 && failedCount > 0) {
    status = SYNC_LOG_STATUS.PARTIAL;
  }

  if (successCount === 0 && failedCount > 0) {
    status = SYNC_LOG_STATUS.FAILED;
  }

  const syncLog = await SyncLog.create({
    entityType: SYNC_ENTITY_TYPES.MEDICINE_TRANSACTION,
    action: SYNC_ACTIONS.BULK_SYNC,
    status,
    rhu: getUserRhuId(req),
    barangay: getUserBarangayId(req),
    user: req.userId,
    deviceId: deviceId || "",
    totalRecords: transactions.length,
    successCount,
    failedCount,
    requestPayload: {
      totalReceived: transactions.length,
      deviceId: deviceId || "",
    },
    responsePayload: {
      results,
    },
    errorMessage:
      failedCount > 0
        ? "Some offline transactions failed to sync."
        : "",
    startedAt,
    completedAt,
    appVersion: appVersion || "",
    platform: platform || "android",
    ipAddress: req.ip || "",
  });

  return res.status(200).json({
    success: failedCount === 0,
    message:
      failedCount === 0
        ? "Medicine transactions synced successfully."
        : "Medicine transaction sync completed with some failed records.",
    syncLogId: syncLog._id,
    totalRecords: transactions.length,
    successCount,
    failedCount,
    results,
  });
});

const getSyncLogs = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = {};

  if (req.query.entityType) {
    filter.entityType = req.query.entityType;
  }

  if (req.query.status) {
    filter.status = req.query.status;
  }

  if (req.query.deviceId) {
    filter.deviceId = req.query.deviceId;
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    filter.rhu = getUserRhuId(req);
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    filter.user = req.userId;
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    if (req.query.rhu) {
      filter.rhu = req.query.rhu;
    }

    if (req.query.barangay) {
      filter.barangay = req.query.barangay;
    }

    if (req.query.user) {
      filter.user = req.query.user;
    }
  }

  const [logs, total] = await Promise.all([
    SyncLog.find(filter)
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .populate("user", "fullName email role")
      .sort({ startedAt: -1 })
      .skip(skip)
      .limit(limit),
    SyncLog.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Sync logs fetched successfully.",
    count: logs.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: logs,
  });
});

const getSyncLogById = asyncHandler(async (req, res) => {
  const log = await SyncLog.findById(req.params.id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("user", "fullName email role");

  if (!log) {
    return res.status(404).json({
      success: false,
      message: "Sync log not found.",
    });
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getIdString(log.rhu) !== getUserRhuId(req)) {
      return res.status(403).json({
        success: false,
        message: "You can only view sync logs under your assigned RHU.",
      });
    }
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (getIdString(log.user) !== req.userId.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only view your own sync logs.",
      });
    }
  }

  return res.status(200).json({
    success: true,
    message: "Sync log fetched successfully.",
    data: log,
  });
});

const getSyncStatus = asyncHandler(async (req, res) => {
  const filter = {};

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    filter.rhu = getUserRhuId(req);
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    filter.user = req.userId;
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    if (req.query.rhu) {
      filter.rhu = req.query.rhu;
    }

    if (req.query.barangay) {
      filter.barangay = req.query.barangay;
    }
  }

  const [totalLogs, successLogs, failedLogs, partialLogs, latestLog] =
    await Promise.all([
      SyncLog.countDocuments(filter),
      SyncLog.countDocuments({
        ...filter,
        status: SYNC_LOG_STATUS.SUCCESS,
      }),
      SyncLog.countDocuments({
        ...filter,
        status: SYNC_LOG_STATUS.FAILED,
      }),
      SyncLog.countDocuments({
        ...filter,
        status: SYNC_LOG_STATUS.PARTIAL,
      }),
      SyncLog.findOne(filter)
        .sort({ startedAt: -1 })
        .populate("rhu", "name code municipality province")
        .populate("barangay", "name code municipality province")
        .populate("user", "fullName email role"),
    ]);

  return res.status(200).json({
    success: true,
    message: "Sync status fetched successfully.",
    data: {
      totalLogs,
      successLogs,
      failedLogs,
      partialLogs,
      latestLog,
    },
  });
});

module.exports = {
  syncMedicineTransactions,
  getSyncLogs,
  getSyncLogById,
  getSyncStatus,
};