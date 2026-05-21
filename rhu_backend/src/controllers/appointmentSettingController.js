const AppointmentSetting = require("../models/AppointmentSetting");
const RHU = require("../models/RHU");
const { asyncHandler } = require("../middleware/errorMiddleware");
const { USER_ROLES } = require("../utils/constants");

const getObjectIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getObjectIdString(req.user?.rhu);

const buildDefaultSetting = async (rhuId, updatedBy = null) => {
  return AppointmentSetting.findOneAndUpdate(
    {
      rhu: rhuId,
    },
    {
      $setOnInsert: {
        rhu: rhuId,
        updatedBy,
      },
    },
    {
      new: true,
      upsert: true,
      runValidators: true,
    }
  ).populate("rhu", "name code municipality province contactNumber email");
};

const canViewRhuSetting = (req, rhuId) => {
  if (!req.user) {
    return {
      allowed: false,
      message: "You are not authorized to view appointment settings.",
    };
  }

  if (
    req.user.role === USER_ROLES.PUBLIC_USER ||
    req.user.role === USER_ROLES.IPHO_ADMIN
  ) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === rhuId.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message:
        "RHU Admin can only view appointment settings under their assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (getUserRhuId(req) === rhuId.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message:
        "Health workers can only view appointment settings under their assigned RHU.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to view appointment settings.",
  };
};

const canManageRhuSetting = (req, rhuId) => {
  if (!req.user) {
    return {
      allowed: false,
      message: "You are not authorized to manage appointment settings.",
    };
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === rhuId.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message:
        "RHU Admin can only manage appointment settings under their assigned RHU.",
    };
  }

  return {
    allowed: false,
    message: "Only IPHO Admin or RHU Admin can manage appointment settings.",
  };
};

const sanitizeTime = (value, fallback) => {
  if (!value || typeof value !== "string") {
    return fallback;
  }

  const trimmed = value.trim();

  if (!/^\d{2}:\d{2}$/.test(trimmed)) {
    return fallback;
  }

  const [hour, minute] = trimmed.split(":").map(Number);

  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return fallback;
  }

  return trimmed;
};

const buildUpdatePayload = (body) => {
  const allowedBooleanFields = [
    "isAcceptingAppointments",
    "allowWalkIn",
    "allowOnline",
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
  ];

  const allowedStringFields = [
    "unavailableReason",
    "instructionsForPatients",
  ];

  const allowedNumberFields = [
    "maxWalkInPerDay",
    "maxOnlinePerDay",
  ];

  const updates = {};

  for (const field of allowedBooleanFields) {
    if (Object.prototype.hasOwnProperty.call(body, field)) {
      updates[field] = Boolean(body[field]);
    }
  }

  for (const field of allowedStringFields) {
    if (Object.prototype.hasOwnProperty.call(body, field)) {
      updates[field] = body[field] || "";
    }
  }

  for (const field of allowedNumberFields) {
    if (Object.prototype.hasOwnProperty.call(body, field)) {
      const value = Number(body[field]);

      if (!Number.isNaN(value) && value >= 0) {
        updates[field] = value;
      }
    }
  }

  if (Object.prototype.hasOwnProperty.call(body, "walkInStartTime")) {
    updates.walkInStartTime = sanitizeTime(body.walkInStartTime, "08:00");
  }

  if (Object.prototype.hasOwnProperty.call(body, "walkInEndTime")) {
    updates.walkInEndTime = sanitizeTime(body.walkInEndTime, "17:00");
  }

  if (Object.prototype.hasOwnProperty.call(body, "onlineStartTime")) {
    updates.onlineStartTime = sanitizeTime(body.onlineStartTime, "08:00");
  }

  if (Object.prototype.hasOwnProperty.call(body, "onlineEndTime")) {
    updates.onlineEndTime = sanitizeTime(body.onlineEndTime, "17:00");
  }

  return updates;
};

const getAppointmentSettingByRHU = asyncHandler(async (req, res) => {
  const { rhuId } = req.params;

  const rhu = await RHU.findById(rhuId);

  if (!rhu) {
    return res.status(404).json({
      success: false,
      message: "RHU not found.",
    });
  }

  const access = canViewRhuSetting(req, rhuId);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const setting = await buildDefaultSetting(rhuId, req.userId);

  return res.status(200).json({
    success: true,
    message: "Appointment setting fetched successfully.",
    data: setting.toSafeObject ? setting.toSafeObject() : setting,
  });
});

const getMyAppointmentSetting = asyncHandler(async (req, res) => {
  const rhuId = getUserRhuId(req);

  if (!rhuId) {
    return res.status(400).json({
      success: false,
      message: "Your account is not assigned to an RHU.",
    });
  }

  const access = canViewRhuSetting(req, rhuId);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const setting = await buildDefaultSetting(rhuId, req.userId);

  return res.status(200).json({
    success: true,
    message: "Your RHU appointment setting fetched successfully.",
    data: setting.toSafeObject ? setting.toSafeObject() : setting,
  });
});

const updateMyAppointmentSetting = asyncHandler(async (req, res) => {
  const rhuId = getUserRhuId(req);

  if (!rhuId) {
    return res.status(400).json({
      success: false,
      message: "Your account is not assigned to an RHU.",
    });
  }

  const access = canManageRhuSetting(req, rhuId);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const updates = buildUpdatePayload(req.body);
  updates.updatedBy = req.userId;

  const setting = await AppointmentSetting.findOneAndUpdate(
    {
      rhu: rhuId,
    },
    {
      $set: updates,
      $setOnInsert: {
        rhu: rhuId,
      },
    },
    {
      new: true,
      upsert: true,
      runValidators: true,
    }
  )
    .populate("rhu", "name code municipality province contactNumber email")
    .populate("updatedBy", "fullName email role");

  return res.status(200).json({
    success: true,
    message: "Appointment setting updated successfully.",
    data: setting.toSafeObject ? setting.toSafeObject() : setting,
  });
});

const updateAppointmentSettingByRHU = asyncHandler(async (req, res) => {
  const { rhuId } = req.params;

  const rhu = await RHU.findById(rhuId);

  if (!rhu) {
    return res.status(404).json({
      success: false,
      message: "RHU not found.",
    });
  }

  const access = canManageRhuSetting(req, rhuId);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const updates = buildUpdatePayload(req.body);
  updates.updatedBy = req.userId;

  const setting = await AppointmentSetting.findOneAndUpdate(
    {
      rhu: rhuId,
    },
    {
      $set: updates,
      $setOnInsert: {
        rhu: rhuId,
      },
    },
    {
      new: true,
      upsert: true,
      runValidators: true,
    }
  )
    .populate("rhu", "name code municipality province contactNumber email")
    .populate("updatedBy", "fullName email role");

  return res.status(200).json({
    success: true,
    message: "Appointment setting updated successfully.",
    data: setting.toSafeObject ? setting.toSafeObject() : setting,
  });
});

module.exports = {
  getAppointmentSettingByRHU,
  getMyAppointmentSetting,
  updateMyAppointmentSetting,
  updateAppointmentSettingByRHU,
};