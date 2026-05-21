const Barangay = require("../models/Barangay");
const RHU = require("../models/RHU");
const User = require("../models/User");
const Medicine = require("../models/Medicine");
const MedicineTransaction = require("../models/MedicineTransaction");
const { asyncHandler } = require("../middleware/errorMiddleware");
const { USER_ROLES } = require("../utils/constants");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);
const getUserBarangayId = (req) => getIdString(req.user?.barangay);

const checkBarangayAccess = (req, barangay) => {
  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    const userRhuId = getUserRhuId(req);

    if (userRhuId === barangay.rhu.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access barangays under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    const userBarangayId = getUserBarangayId(req);

    if (userBarangayId === barangay._id.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access your assigned barangay.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to access this barangay.",
  };
};

const buildBarangayFilter = (req) => {
  const filter = {
    isActive: true,
  };

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    filter.rhu = getUserRhuId(req);
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    filter._id = getUserBarangayId(req);
  }

  if (req.query.rhu && req.user.role === USER_ROLES.IPHO_ADMIN) {
    filter.rhu = req.query.rhu;
  }

  if (req.query.search) {
    const searchRegex = new RegExp(req.query.search.trim(), "i");

    filter.$or = [
      { name: searchRegex },
      { code: searchRegex },
      { municipality: searchRegex },
    ];
  }

  return filter;
};

const getAllBarangays = asyncHandler(async (req, res) => {
  const filter = buildBarangayFilter(req);

  const barangays = await Barangay.find(filter)
    .populate("rhu", "name code municipality province")
    .populate("assignedHealthWorkers", "fullName email role isActive")
    .sort({ municipality: 1, name: 1 });

  return res.status(200).json({
    success: true,
    message: "Barangays fetched successfully.",
    count: barangays.length,
    data: barangays,
  });
});

const getBarangaysByRHU = asyncHandler(async (req, res) => {
  const { rhuId } = req.params;

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    const userRhuId = getUserRhuId(req);

    if (userRhuId !== rhuId.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only view barangays under your assigned RHU.",
      });
    }
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    const userRhuId = getUserRhuId(req);

    if (userRhuId !== rhuId.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only view barangays under your assigned RHU.",
      });
    }
  }

  const rhu = await RHU.findById(rhuId);

  if (!rhu || !rhu.isActive) {
    return res.status(404).json({
      success: false,
      message: "RHU not found.",
    });
  }

  const filter = {
    rhu: rhuId,
    isActive: true,
  };

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    filter._id = getUserBarangayId(req);
  }

  const barangays = await Barangay.find(filter)
    .populate("rhu", "name code municipality province")
    .populate("assignedHealthWorkers", "fullName email role isActive")
    .sort({ name: 1 });

  return res.status(200).json({
    success: true,
    message: "Barangays under RHU fetched successfully.",
    count: barangays.length,
    data: barangays,
  });
});

const getBarangayById = asyncHandler(async (req, res) => {
  const barangay = await Barangay.findById(req.params.id)
    .populate("rhu", "name code municipality province")
    .populate("assignedHealthWorkers", "fullName email role isActive phoneNumber position");

  if (!barangay || !barangay.isActive) {
    return res.status(404).json({
      success: false,
      message: "Barangay not found.",
    });
  }

  const access = checkBarangayAccess(req, {
    ...barangay.toObject(),
    rhu: barangay.rhu._id,
  });

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  return res.status(200).json({
    success: true,
    message: "Barangay fetched successfully.",
    data: barangay,
  });
});

const createBarangay = asyncHandler(async (req, res) => {
  const {
    name,
    code,
    rhu,
    municipality,
    province,
    address,
    contactNumber,
  } = req.body;

  if (!rhu) {
    return res.status(400).json({
      success: false,
      message: "RHU is required.",
    });
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    const userRhuId = getUserRhuId(req);

    if (userRhuId !== rhu.toString()) {
      return res.status(403).json({
        success: false,
        message: "RHU admins can only create barangays under their assigned RHU.",
      });
    }
  }

  const existingRHU = await RHU.findById(rhu);

  if (!existingRHU || !existingRHU.isActive) {
    return res.status(404).json({
      success: false,
      message: "RHU not found or inactive.",
    });
  }

  const barangay = await Barangay.create({
    name,
    code,
    rhu,
    municipality: municipality || existingRHU.municipality,
    province,
    address,
    contactNumber,
    createdBy: req.userId,
  });

  await RHU.findByIdAndUpdate(rhu, {
    $inc: { barangayCount: 1 },
  });

  const createdBarangay = await Barangay.findById(barangay._id).populate(
    "rhu",
    "name code municipality province"
  );

  return res.status(201).json({
    success: true,
    message: "Barangay created successfully.",
    data: createdBarangay,
  });
});

const updateBarangay = asyncHandler(async (req, res) => {
  const barangay = await Barangay.findById(req.params.id);

  if (!barangay || !barangay.isActive) {
    return res.status(404).json({
      success: false,
      message: "Barangay not found.",
    });
  }

  const access = checkBarangayAccess(req, barangay);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    return res.status(403).json({
      success: false,
      message: "Barangay health workers cannot update barangay profile details.",
    });
  }

  const allowedUpdates = [
    "name",
    "municipality",
    "province",
    "address",
    "contactNumber",
    "isActive",
  ];

  const updates = {};

  for (const field of allowedUpdates) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      updates[field] = req.body[field];
    }
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    delete updates.isActive;
  }

  const updatedBarangay = await Barangay.findByIdAndUpdate(
    req.params.id,
    updates,
    {
      new: true,
      runValidators: true,
    }
  )
    .populate("rhu", "name code municipality province")
    .populate("assignedHealthWorkers", "fullName email role isActive");

  return res.status(200).json({
    success: true,
    message: "Barangay updated successfully.",
    data: updatedBarangay,
  });
});

const deactivateBarangay = asyncHandler(async (req, res) => {
  const barangay = await Barangay.findById(req.params.id);

  if (!barangay) {
    return res.status(404).json({
      success: false,
      message: "Barangay not found.",
    });
  }

  const access = checkBarangayAccess(req, barangay);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role !== USER_ROLES.IPHO_ADMIN && req.user.role !== USER_ROLES.RHU_ADMIN) {
    return res.status(403).json({
      success: false,
      message: "Only IPHO admins and RHU admins can deactivate barangays.",
    });
  }

  barangay.isActive = false;
  await barangay.save();

  await User.updateMany(
    {
      barangay: barangay._id,
    },
    {
      isActive: false,
    }
  );

  await RHU.findByIdAndUpdate(barangay.rhu, {
    $inc: { barangayCount: -1 },
  });

  return res.status(200).json({
    success: true,
    message: "Barangay deactivated successfully. Assigned users were also disabled.",
  });
});

const assignHealthWorkerToBarangay = asyncHandler(async (req, res) => {
  const { barangayId, userId } = req.body;

  if (!barangayId || !userId) {
    return res.status(400).json({
      success: false,
      message: "Barangay ID and user ID are required.",
    });
  }

  const barangay = await Barangay.findById(barangayId);

  if (!barangay || !barangay.isActive) {
    return res.status(404).json({
      success: false,
      message: "Barangay not found.",
    });
  }

  const access = checkBarangayAccess(req, barangay);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role !== USER_ROLES.IPHO_ADMIN && req.user.role !== USER_ROLES.RHU_ADMIN) {
    return res.status(403).json({
      success: false,
      message: "Only IPHO admins and RHU admins can assign health workers.",
    });
  }

  const user = await User.findById(userId);

  if (!user || !user.isActive) {
    return res.status(404).json({
      success: false,
      message: "User not found or inactive.",
    });
  }

  if (user.role !== USER_ROLES.BARANGAY_HEALTH_WORKER) {
    return res.status(400).json({
      success: false,
      message: "Only barangay health worker accounts can be assigned to barangays.",
    });
  }

  user.rhu = barangay.rhu;
  user.barangay = barangay._id;
  await user.save();

  await Barangay.findByIdAndUpdate(barangay._id, {
    $addToSet: {
      assignedHealthWorkers: user._id,
    },
  });

  const updatedBarangay = await Barangay.findById(barangay._id)
    .populate("rhu", "name code municipality province")
    .populate("assignedHealthWorkers", "fullName email role isActive");

  return res.status(200).json({
    success: true,
    message: "Health worker assigned to barangay successfully.",
    data: updatedBarangay,
  });
});

const removeHealthWorkerFromBarangay = asyncHandler(async (req, res) => {
  const { barangayId, userId } = req.body;

  if (!barangayId || !userId) {
    return res.status(400).json({
      success: false,
      message: "Barangay ID and user ID are required.",
    });
  }

  const barangay = await Barangay.findById(barangayId);

  if (!barangay || !barangay.isActive) {
    return res.status(404).json({
      success: false,
      message: "Barangay not found.",
    });
  }

  const access = checkBarangayAccess(req, barangay);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role !== USER_ROLES.IPHO_ADMIN && req.user.role !== USER_ROLES.RHU_ADMIN) {
    return res.status(403).json({
      success: false,
      message: "Only IPHO admins and RHU admins can remove health workers.",
    });
  }

  await Barangay.findByIdAndUpdate(barangay._id, {
    $pull: {
      assignedHealthWorkers: userId,
    },
  });

  await User.findByIdAndUpdate(userId, {
    barangay: null,
  });

  const updatedBarangay = await Barangay.findById(barangay._id)
    .populate("rhu", "name code municipality province")
    .populate("assignedHealthWorkers", "fullName email role isActive");

  return res.status(200).json({
    success: true,
    message: "Health worker removed from barangay successfully.",
    data: updatedBarangay,
  });
});

const getBarangaySummary = asyncHandler(async (req, res) => {
  const barangay = await Barangay.findById(req.params.id).populate(
    "rhu",
    "name code municipality province"
  );

  if (!barangay || !barangay.isActive) {
    return res.status(404).json({
      success: false,
      message: "Barangay not found.",
    });
  }

  const access = checkBarangayAccess(req, {
    ...barangay.toObject(),
    rhu: barangay.rhu._id,
  });

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const [
    activeHealthWorkerCount,
    medicineCount,
    lowStockCount,
    outOfStockCount,
    expiredCount,
    transactionCount,
    receivedCount,
    dispensedCount,
    adjustedCount,
  ] = await Promise.all([
    User.countDocuments({
      barangay: barangay._id,
      role: USER_ROLES.BARANGAY_HEALTH_WORKER,
      isActive: true,
    }),
    Medicine.countDocuments({
      barangay: barangay._id,
      isActive: true,
    }),
    Medicine.countDocuments({
      barangay: barangay._id,
      isActive: true,
      stockStatus: "low_stock",
    }),
    Medicine.countDocuments({
      barangay: barangay._id,
      isActive: true,
      stockStatus: "out_of_stock",
    }),
    Medicine.countDocuments({
      barangay: barangay._id,
      isActive: true,
      stockStatus: "expired",
    }),
    MedicineTransaction.countDocuments({
      barangay: barangay._id,
      isDeleted: false,
    }),
    MedicineTransaction.countDocuments({
      barangay: barangay._id,
      transactionType: "received",
      isDeleted: false,
    }),
    MedicineTransaction.countDocuments({
      barangay: barangay._id,
      transactionType: "dispensed",
      isDeleted: false,
    }),
    MedicineTransaction.countDocuments({
      barangay: barangay._id,
      transactionType: "adjusted",
      isDeleted: false,
    }),
  ]);

  return res.status(200).json({
    success: true,
    message: "Barangay summary fetched successfully.",
    data: {
      barangay,
      counts: {
        activeHealthWorkers: activeHealthWorkerCount,
        medicines: medicineCount,
        lowStockMedicines: lowStockCount,
        outOfStockMedicines: outOfStockCount,
        expiredMedicines: expiredCount,
        medicineTransactions: transactionCount,
        receivedTransactions: receivedCount,
        dispensedTransactions: dispensedCount,
        adjustedTransactions: adjustedCount,
      },
    },
  });
});

module.exports = {
  getAllBarangays,
  getBarangaysByRHU,
  getBarangayById,
  createBarangay,
  updateBarangay,
  deactivateBarangay,
  assignHealthWorkerToBarangay,
  removeHealthWorkerFromBarangay,
  getBarangaySummary,
};