const RHU = require("../models/RHU");
const Barangay = require("../models/Barangay");
const User = require("../models/User");
const Medicine = require("../models/Medicine");
const MedicineTransaction = require("../models/MedicineTransaction");
const { asyncHandler } = require("../middleware/errorMiddleware");
const { USER_ROLES } = require("../utils/constants");

const buildRhuFilter = (req) => {
  const filter = {
    isActive: true,
  };

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    filter._id = req.user.rhu?._id || req.user.rhu;
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

const getAllRHUs = asyncHandler(async (req, res) => {
  const filter = buildRhuFilter(req);

  const rhus = await RHU.find(filter).sort({ municipality: 1, name: 1 });

  return res.status(200).json({
    success: true,
    message: "RHUs fetched successfully.",
    count: rhus.length,
    data: rhus,
  });
});

const getRHUById = asyncHandler(async (req, res) => {
  const rhu = await RHU.findById(req.params.id);

  if (!rhu || !rhu.isActive) {
    return res.status(404).json({
      success: false,
      message: "RHU not found.",
    });
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    const userRhuId = req.user.rhu?._id
      ? req.user.rhu._id.toString()
      : req.user.rhu?.toString();

    if (userRhuId !== rhu._id.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only view your assigned RHU.",
      });
    }
  }

  return res.status(200).json({
    success: true,
    message: "RHU fetched successfully.",
    data: rhu,
  });
});

const createRHU = asyncHandler(async (req, res) => {
  const {
    name,
    code,
    municipality,
    province,
    barangayCount,
    address,
    contactNumber,
    email,
  } = req.body;

  const rhu = await RHU.create({
    name,
    code,
    municipality,
    province,
    barangayCount,
    address,
    contactNumber,
    email,
    createdBy: req.userId,
  });

  return res.status(201).json({
    success: true,
    message: "RHU created successfully.",
    data: rhu,
  });
});

const updateRHU = asyncHandler(async (req, res) => {
  const allowedUpdates = [
    "name",
    "municipality",
    "province",
    "barangayCount",
    "address",
    "contactNumber",
    "email",
    "isActive",
  ];

  const updates = {};

  for (const field of allowedUpdates) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      updates[field] = req.body[field];
    }
  }

  const rhu = await RHU.findById(req.params.id);

  if (!rhu) {
    return res.status(404).json({
      success: false,
      message: "RHU not found.",
    });
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    const userRhuId = req.user.rhu?._id
      ? req.user.rhu._id.toString()
      : req.user.rhu?.toString();

    if (userRhuId !== rhu._id.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only update your assigned RHU.",
      });
    }

    delete updates.isActive;
  }

  const updatedRHU = await RHU.findByIdAndUpdate(req.params.id, updates, {
    new: true,
    runValidators: true,
  });

  return res.status(200).json({
    success: true,
    message: "RHU updated successfully.",
    data: updatedRHU,
  });
});

const deactivateRHU = asyncHandler(async (req, res) => {
  const rhu = await RHU.findById(req.params.id);

  if (!rhu) {
    return res.status(404).json({
      success: false,
      message: "RHU not found.",
    });
  }

  rhu.isActive = false;
  await rhu.save();

  await Barangay.updateMany(
    { rhu: rhu._id },
    { isActive: false }
  );

  await User.updateMany(
    { rhu: rhu._id },
    { isActive: false }
  );

  return res.status(200).json({
    success: true,
    message: "RHU deactivated successfully. Related barangays and users were also disabled.",
  });
});

const getRHUSummary = asyncHandler(async (req, res) => {
  const rhuId = req.params.id;

  const rhu = await RHU.findById(rhuId);

  if (!rhu || !rhu.isActive) {
    return res.status(404).json({
      success: false,
      message: "RHU not found.",
    });
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    const userRhuId = req.user.rhu?._id
      ? req.user.rhu._id.toString()
      : req.user.rhu?.toString();

    if (userRhuId !== rhuId.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only view summary for your assigned RHU.",
      });
    }
  }

  const [
    barangayCount,
    activeHealthWorkerCount,
    medicineCount,
    lowStockCount,
    outOfStockCount,
    expiredCount,
    transactionCount,
  ] = await Promise.all([
    Barangay.countDocuments({ rhu: rhuId, isActive: true }),
    User.countDocuments({
      rhu: rhuId,
      role: USER_ROLES.BARANGAY_HEALTH_WORKER,
      isActive: true,
    }),
    Medicine.countDocuments({ rhu: rhuId, isActive: true }),
    Medicine.countDocuments({
      rhu: rhuId,
      isActive: true,
      stockStatus: "low_stock",
    }),
    Medicine.countDocuments({
      rhu: rhuId,
      isActive: true,
      stockStatus: "out_of_stock",
    }),
    Medicine.countDocuments({
      rhu: rhuId,
      isActive: true,
      stockStatus: "expired",
    }),
    MedicineTransaction.countDocuments({
      rhu: rhuId,
      isDeleted: false,
    }),
  ]);

  return res.status(200).json({
    success: true,
    message: "RHU summary fetched successfully.",
    data: {
      rhu,
      counts: {
        barangays: barangayCount,
        activeHealthWorkers: activeHealthWorkerCount,
        medicines: medicineCount,
        lowStockMedicines: lowStockCount,
        outOfStockMedicines: outOfStockCount,
        expiredMedicines: expiredCount,
        medicineTransactions: transactionCount,
      },
    },
  });
});

module.exports = {
  getAllRHUs,
  getRHUById,
  createRHU,
  updateRHU,
  deactivateRHU,
  getRHUSummary,
};