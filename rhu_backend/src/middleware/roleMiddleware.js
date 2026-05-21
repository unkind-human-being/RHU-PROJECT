const { USER_ROLES, ERROR_MESSAGES } = require("../utils/constants");

const allowRoles = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: ERROR_MESSAGES.UNAUTHORIZED,
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: ERROR_MESSAGES.FORBIDDEN,
      });
    }

    next();
  };
};

const isIPHOAdmin = allowRoles(USER_ROLES.IPHO_ADMIN);

const isRHUAdmin = allowRoles(USER_ROLES.RHU_ADMIN);

const isBarangayHealthWorker = allowRoles(USER_ROLES.BARANGAY_HEALTH_WORKER);

const isPharmacist = allowRoles(USER_ROLES.PHARMACIST);

const isStaff = allowRoles(
  USER_ROLES.IPHO_ADMIN,
  USER_ROLES.RHU_ADMIN,
  USER_ROLES.BARANGAY_HEALTH_WORKER
);

const isAdmin = allowRoles(
  USER_ROLES.IPHO_ADMIN,
  USER_ROLES.RHU_ADMIN
);

const canManageRHU = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      message: ERROR_MESSAGES.UNAUTHORIZED,
    });
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return next();
  }

  if (req.user.role !== USER_ROLES.RHU_ADMIN) {
    return res.status(403).json({
      success: false,
      message: ERROR_MESSAGES.FORBIDDEN,
    });
  }

  const requestedRhuId =
    req.params.rhuId ||
    req.params.id ||
    req.body.rhu ||
    req.query.rhu;

  if (!requestedRhuId) {
    return next();
  }

  const userRhuId = req.user.rhu?._id
    ? req.user.rhu._id.toString()
    : req.user.rhu?.toString();

  if (userRhuId !== requestedRhuId.toString()) {
    return res.status(403).json({
      success: false,
      message: "You can only manage data under your assigned RHU.",
    });
  }

  next();
};

const canManageBarangay = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      message: ERROR_MESSAGES.UNAUTHORIZED,
    });
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return next();
  }

  const requestedRhuId =
    req.params.rhuId ||
    req.body.rhu ||
    req.query.rhu;

  const requestedBarangayId =
    req.params.barangayId ||
    req.params.id ||
    req.body.barangay ||
    req.query.barangay;

  const userRhuId = req.user.rhu?._id
    ? req.user.rhu._id.toString()
    : req.user.rhu?.toString();

  const userBarangayId = req.user.barangay?._id
    ? req.user.barangay._id.toString()
    : req.user.barangay?.toString();

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (requestedRhuId && userRhuId !== requestedRhuId.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only manage barangays under your assigned RHU.",
      });
    }

    return next();
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (
      requestedBarangayId &&
      userBarangayId !== requestedBarangayId.toString()
    ) {
      return res.status(403).json({
        success: false,
        message: "You can only manage data under your assigned barangay.",
      });
    }

    if (requestedRhuId && userRhuId !== requestedRhuId.toString()) {
      return res.status(403).json({
        success: false,
        message: "You can only manage data under your assigned RHU.",
      });
    }

    return next();
  }

  return res.status(403).json({
    success: false,
    message: ERROR_MESSAGES.FORBIDDEN,
  });
};

const canCreateHealthWorkerAccount = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      message: ERROR_MESSAGES.UNAUTHORIZED,
    });
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return next();
  }

  if (req.user.role !== USER_ROLES.RHU_ADMIN) {
    return res.status(403).json({
      success: false,
      message: ERROR_MESSAGES.FORBIDDEN,
    });
  }

  const requestedRhuId = req.body.rhu;

  if (!requestedRhuId) {
    return res.status(400).json({
      success: false,
      message: "RHU is required when creating a health worker account.",
    });
  }

  const userRhuId = req.user.rhu?._id
    ? req.user.rhu._id.toString()
    : req.user.rhu?.toString();

  if (userRhuId !== requestedRhuId.toString()) {
    return res.status(403).json({
      success: false,
      message: "RHU admins can only create health worker accounts under their own RHU.",
    });
  }

  next();
};



const canCreatePharmacistAccount = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      message: ERROR_MESSAGES.UNAUTHORIZED,
    });
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return next();
  }

  if (req.user.role !== USER_ROLES.RHU_ADMIN) {
    return res.status(403).json({
      success: false,
      message: ERROR_MESSAGES.FORBIDDEN,
    });
  }

  const requestedRhuId = req.body.rhu;

  if (!requestedRhuId) {
    return res.status(400).json({
      success: false,
      message: "RHU is required when creating a pharmacist account.",
    });
  }

  const userRhuId = req.user.rhu?._id
    ? req.user.rhu._id.toString()
    : req.user.rhu?.toString();

  if (userRhuId !== requestedRhuId.toString()) {
    return res.status(403).json({
      success: false,
      message:
        "RHU admins can only create pharmacist accounts under their own RHU.",
    });
  }

  next();
};


module.exports = {
  allowRoles,
  isIPHOAdmin,
  isRHUAdmin,
  isBarangayHealthWorker,
  isStaff,
  isAdmin,
  canManageRHU,
  canManageBarangay,
  canCreateHealthWorkerAccount,
  isPharmacist,
  canCreatePharmacistAccount,
};