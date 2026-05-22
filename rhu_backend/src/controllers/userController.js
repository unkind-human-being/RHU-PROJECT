const User = require("../models/User");
const RHU = require("../models/RHU");
const Barangay = require("../models/Barangay");
const { asyncHandler } = require("../middleware/errorMiddleware");
const { USER_ROLES } = require("../utils/constants");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);
const getUserBarangayId = (req) => getIdString(req.user?.barangay);

const sanitizeUser = (user) => {
  const safeUser = user.toObject ? user.toObject() : user;

  delete safeUser.password;
  delete safeUser.__v;

  return safeUser;
};

const getRhuAdminManageableRoles = () => [
  USER_ROLES.BARANGAY_HEALTH_WORKER,
  USER_ROLES.PHARMACIST,
];

const buildUserFilter = (req) => {
  const filter = {};

  if (req.query.role) {
    filter.role = req.query.role;
  }

  if (req.query.isActive === "true") {
    filter.isActive = true;
  }

  if (req.query.isActive === "false") {
    filter.isActive = false;
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    filter.rhu = getUserRhuId(req);

    if (!filter.role) {
      filter.role = {
        $in: [
          USER_ROLES.RHU_ADMIN,
          USER_ROLES.BARANGAY_HEALTH_WORKER,
          USER_ROLES.PHARMACIST,
        ],
      };
    }
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    filter._id = req.userId;
  }

  if (req.user.role === USER_ROLES.PHARMACIST) {
    filter._id = req.userId;
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    if (req.query.rhu) {
      filter.rhu = req.query.rhu;
    }

    if (req.query.barangay) {
      filter.barangay = req.query.barangay;
    }
  }

  if (req.query.search) {
    const searchRegex = new RegExp(req.query.search.trim(), "i");

    filter.$or = [
      { fullName: searchRegex },
      { email: searchRegex },
      { position: searchRegex },
      { phoneNumber: searchRegex },
    ];
  }

  return filter;
};

const canAccessUser = (req, targetUser) => {
  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    const currentUserRhuId = getUserRhuId(req);
    const targetUserRhuId = getIdString(targetUser.rhu);

    if (currentUserRhuId === targetUserRhuId) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access users under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (req.userId.toString() === targetUser._id.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access your own account.",
    };
  }

  if (req.user.role === USER_ROLES.PHARMACIST) {
    if (req.userId.toString() === targetUser._id.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access your own account.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to access this user.",
  };
};

const validateUserAssignment = async ({ role, rhu, barangay, req }) => {
  if (role === USER_ROLES.IPHO_ADMIN) {
    return {
      rhu: null,
      barangay: null,
    };
  }

  if (role === USER_ROLES.PUBLIC_USER) {
    return {
      rhu: null,
      barangay: null,
    };
  }

  if (role === USER_ROLES.RHU_ADMIN) {
    if (!rhu) {
      throw new Error("RHU is required for RHU admin accounts.");
    }

    const existingRHU = await RHU.findById(rhu);

    if (!existingRHU || !existingRHU.isActive) {
      throw new Error("Selected RHU does not exist or is inactive.");
    }

    if (req.user.role === USER_ROLES.RHU_ADMIN) {
      throw new Error("RHU admins cannot create another RHU admin account.");
    }

    return {
      rhu,
      barangay: null,
    };
  }

  if (role === USER_ROLES.PHARMACIST) {
    if (!rhu) {
      throw new Error("RHU is required for pharmacist accounts.");
    }

    const existingRHU = await RHU.findById(rhu);

    if (!existingRHU || !existingRHU.isActive) {
      throw new Error("Selected RHU does not exist or is inactive.");
    }

    if (req.user.role === USER_ROLES.RHU_ADMIN) {
      const currentUserRhuId = getUserRhuId(req);

      if (currentUserRhuId !== rhu.toString()) {
        throw new Error(
          "RHU admins can only create pharmacist accounts under their own RHU."
        );
      }
    }

    return {
      rhu,
      barangay: null,
    };
  }

  if (role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (!rhu || !barangay) {
      throw new Error(
        "RHU and barangay are required for barangay health worker accounts."
      );
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

    if (req.user.role === USER_ROLES.RHU_ADMIN) {
      const currentUserRhuId = getUserRhuId(req);

      if (currentUserRhuId !== rhu.toString()) {
        throw new Error(
          "RHU admins can only create health workers under their own RHU."
        );
      }
    }

    return {
      rhu,
      barangay,
    };
  }

  throw new Error("Invalid user role.");
};

const getUsers = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = buildUserFilter(req);

  const [users, total] = await Promise.all([
    User.find(filter)
      .select("-password")
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
    User.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Users fetched successfully.",
    count: users.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: users,
  });
});

const getUserById = asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id)
    .select("-password")
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province");

  if (!user) {
    return res.status(404).json({
      success: false,
      message: "User not found.",
    });
  }

  const access = canAccessUser(req, user);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  return res.status(200).json({
    success: true,
    message: "User fetched successfully.",
    data: sanitizeUser(user),
  });
});

const createUser = asyncHandler(async (req, res) => {
  const {
    fullName,
    email,
    password,
    role,
    rhu,
    barangay,
    position,
    phoneNumber,
  } = req.body;

  if (!fullName || !email || !password || !role) {
    return res.status(400).json({
      success: false,
      message: "Full name, email, password, and role are required.",
    });
  }

  if (password.length < 8) {
    return res.status(400).json({
      success: false,
      message: "Password must be at least 8 characters.",
    });
  }

  if (!Object.values(USER_ROLES).includes(role)) {
    return res.status(400).json({
      success: false,
      message: "Invalid user role.",
    });
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    const allowedRhuAdminCreatedRoles = getRhuAdminManageableRoles();

    if (!allowedRhuAdminCreatedRoles.includes(role)) {
      return res.status(403).json({
        success: false,
        message:
          "RHU admins can only create barangay health worker or pharmacist accounts.",
      });
    }
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    return res.status(403).json({
      success: false,
      message: "Barangay health workers cannot create user accounts.",
    });
  }

  if (req.user.role === USER_ROLES.PHARMACIST) {
    return res.status(403).json({
      success: false,
      message: "Pharmacists cannot create user accounts.",
    });
  }

  const existingUser = await User.findOne({
    email: email.toLowerCase().trim(),
  });

  if (existingUser) {
    return res.status(409).json({
      success: false,
      message: "Email already exists.",
    });
  }

  let assignment;

  try {
    assignment = await validateUserAssignment({
      role,
      rhu,
      barangay,
      req,
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }

  const user = await User.create({
    fullName,
    email,
    password,
    role,
    rhu: assignment.rhu,
    barangay: assignment.barangay,
    position,
    phoneNumber,
    createdBy: req.userId,
  });

  if (role === USER_ROLES.BARANGAY_HEALTH_WORKER && assignment.barangay) {
    await Barangay.findByIdAndUpdate(assignment.barangay, {
      $addToSet: {
        assignedHealthWorkers: user._id,
      },
    });
  }

  const createdUser = await User.findById(user._id)
    .select("-password")
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province");

  return res.status(201).json({
    success: true,
    message: "User account created successfully.",
    data: sanitizeUser(createdUser),
  });
});

const createHealthWorker = asyncHandler(async (req, res) => {
  req.body.role = USER_ROLES.BARANGAY_HEALTH_WORKER;

  return createUser(req, res);
});

const createPharmacist = asyncHandler(async (req, res) => {
  req.body.role = USER_ROLES.PHARMACIST;
  req.body.barangay = null;

  if (!req.body.position) {
    req.body.position = "Pharmacist";
  }

  return createUser(req, res);
});

const updateUser = asyncHandler(async (req, res) => {
  const targetUser = await User.findById(req.params.id);

  if (!targetUser) {
    return res.status(404).json({
      success: false,
      message: "User not found.",
    });
  }

  const access = canAccessUser(req, targetUser);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    return res.status(403).json({
      success: false,
      message:
        "Barangay health workers cannot update account administration details.",
    });
  }

  if (req.user.role === USER_ROLES.PHARMACIST) {
    return res.status(403).json({
      success: false,
      message: "Pharmacists cannot update account administration details.",
    });
  }

  const allowedUpdates = [
    "fullName",
    "position",
    "phoneNumber",
    "isActive",
    "rhu",
    "barangay",
    "role",
  ];

  const updates = {};

  for (const field of allowedUpdates) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      updates[field] = req.body[field];
    }
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    delete updates.role;
    delete updates.rhu;
    delete updates.isActive;

    const rhuAdminManageableRoles = getRhuAdminManageableRoles();

    if (!rhuAdminManageableRoles.includes(targetUser.role)) {
      return res.status(403).json({
        success: false,
        message:
          "RHU admins can only update barangay health worker or pharmacist accounts.",
      });
    }
  }

  if (
    updates.role ||
    updates.rhu ||
    Object.prototype.hasOwnProperty.call(updates, "barangay")
  ) {
    const newRole = updates.role || targetUser.role;
    const newRhu = updates.rhu || getIdString(targetUser.rhu);
    const newBarangay = Object.prototype.hasOwnProperty.call(updates, "barangay")
      ? updates.barangay
      : getIdString(targetUser.barangay);

    let assignment;

    try {
      assignment = await validateUserAssignment({
        role: newRole,
        rhu: newRhu,
        barangay: newBarangay,
        req,
      });
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }

    updates.role = newRole;
    updates.rhu = assignment.rhu;
    updates.barangay = assignment.barangay;
  }

  const oldBarangayId = getIdString(targetUser.barangay);

  const updatedUser = await User.findByIdAndUpdate(req.params.id, updates, {
    new: true,
    runValidators: true,
  })
    .select("-password")
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province");

  const newBarangayId = getIdString(updatedUser.barangay);

  if (oldBarangayId && oldBarangayId !== newBarangayId) {
    await Barangay.findByIdAndUpdate(oldBarangayId, {
      $pull: {
        assignedHealthWorkers: updatedUser._id,
      },
    });
  }

  if (
    updatedUser.role === USER_ROLES.BARANGAY_HEALTH_WORKER &&
    newBarangayId
  ) {
    await Barangay.findByIdAndUpdate(newBarangayId, {
      $addToSet: {
        assignedHealthWorkers: updatedUser._id,
      },
    });
  }

  return res.status(200).json({
    success: true,
    message: "User updated successfully.",
    data: sanitizeUser(updatedUser),
  });
});

const deactivateUser = asyncHandler(async (req, res) => {
  const targetUser = await User.findById(req.params.id);

  if (!targetUser) {
    return res.status(404).json({
      success: false,
      message: "User not found.",
    });
  }

  const access = canAccessUser(req, targetUser);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (targetUser._id.toString() === req.userId.toString()) {
    return res.status(400).json({
      success: false,
      message: "You cannot deactivate your own account.",
    });
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    const rhuAdminManageableRoles = getRhuAdminManageableRoles();

    if (!rhuAdminManageableRoles.includes(targetUser.role)) {
      return res.status(403).json({
        success: false,
        message:
          "RHU admins can only deactivate barangay health worker or pharmacist accounts.",
      });
    }
  }

  targetUser.isActive = false;
  await targetUser.save();

  if (targetUser.barangay) {
    await Barangay.findByIdAndUpdate(targetUser.barangay, {
      $pull: {
        assignedHealthWorkers: targetUser._id,
      },
    });
  }

  return res.status(200).json({
    success: true,
    message: "User deactivated successfully.",
  });
});

const reactivateUser = asyncHandler(async (req, res) => {
  const targetUser = await User.findById(req.params.id);

  if (!targetUser) {
    return res.status(404).json({
      success: false,
      message: "User not found.",
    });
  }

  const access = canAccessUser(req, targetUser);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    const rhuAdminManageableRoles = getRhuAdminManageableRoles();

    if (!rhuAdminManageableRoles.includes(targetUser.role)) {
      return res.status(403).json({
        success: false,
        message:
          "RHU admins can only reactivate barangay health worker or pharmacist accounts.",
      });
    }
  }

  targetUser.isActive = true;
  await targetUser.save();

  if (
    targetUser.role === USER_ROLES.BARANGAY_HEALTH_WORKER &&
    targetUser.barangay
  ) {
    await Barangay.findByIdAndUpdate(targetUser.barangay, {
      $addToSet: {
        assignedHealthWorkers: targetUser._id,
      },
    });
  }

  return res.status(200).json({
    success: true,
    message: "User reactivated successfully.",
  });
});

const deleteUser = asyncHandler(async (req, res) => {
  const targetUser = await User.findById(req.params.id);

  if (!targetUser) {
    return res.status(404).json({
      success: false,
      message: "User not found.",
    });
  }

  const requesterEmail = req.user?.email?.toLowerCase().trim();

  if (requesterEmail !== "admin@rhu-tawitawi.local") {
    return res.status(403).json({
      success: false,
      message: "Only the main IPHO admin can permanently delete user accounts.",
    });
  }

  if (targetUser.email?.toLowerCase().trim() === "admin@rhu-tawitawi.local") {
    return res.status(400).json({
      success: false,
      message: "The main IPHO admin account cannot be deleted.",
    });
  }

  if (targetUser._id.toString() === req.userId.toString()) {
    return res.status(400).json({
      success: false,
      message: "You cannot delete your own account.",
    });
  }

  if (targetUser.barangay) {
    await Barangay.findByIdAndUpdate(targetUser.barangay, {
      $pull: {
        assignedHealthWorkers: targetUser._id,
      },
    });
  }

  await User.findByIdAndDelete(targetUser._id);

  return res.status(200).json({
    success: true,
    message: "User permanently deleted successfully.",
  });
});

const resetUserPassword = asyncHandler(async (req, res) => {
  const { newPassword } = req.body;

  if (!newPassword) {
    return res.status(400).json({
      success: false,
      message: "New password is required.",
    });
  }

  if (newPassword.length < 8) {
    return res.status(400).json({
      success: false,
      message: "New password must be at least 8 characters.",
    });
  }

  const targetUser = await User.findById(req.params.id).select("+password");

  if (!targetUser) {
    return res.status(404).json({
      success: false,
      message: "User not found.",
    });
  }

  const access = canAccessUser(req, targetUser);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    const rhuAdminManageableRoles = getRhuAdminManageableRoles();

    if (!rhuAdminManageableRoles.includes(targetUser.role)) {
      return res.status(403).json({
        success: false,
        message:
          "RHU admins can only reset barangay health worker or pharmacist passwords.",
      });
    }
  }

  targetUser.password = newPassword;
  await targetUser.save();

  return res.status(200).json({
    success: true,
    message: "User password reset successfully.",
  });
});


const saveFcmToken = asyncHandler(async (req, res) => {
  const { fcmToken, platform = "android", purpose = "incoming_call" } = req.body;

  if (!fcmToken || !fcmToken.trim()) {
    return res.status(400).json({
      success: false,
      message: "FCM token is required.",
    });
  }

  const user = await User.findById(req.userId);

  if (!user) {
    return res.status(404).json({
      success: false,
      message: "User not found.",
    });
  }

  user.fcmTokens = user.fcmTokens || [];

  user.fcmTokens = user.fcmTokens.filter((item) => {
    return item.token !== fcmToken.trim();
  });

  user.fcmTokens.push({
    token: fcmToken.trim(),
    platform,
    purpose,
    lastUsedAt: new Date(),
  });

  await user.save();

  return res.status(200).json({
    success: true,
    message: "FCM token saved successfully.",
  });
});



module.exports = {
  getUsers,
  getUserById,
  createUser,
  createHealthWorker,
  createPharmacist,
  updateUser,
  deactivateUser,
  reactivateUser,
  deleteUser,
  resetUserPassword,
  saveFcmToken,
};