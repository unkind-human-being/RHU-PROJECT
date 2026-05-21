const Appointment = require("../models/Appointment");
const { USER_ROLES } = require("../utils/constants");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const formatRemainingTime = (milliseconds) => {
  const totalMinutes = Math.ceil(milliseconds / 60000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;

  if (hours <= 0) {
    return `${minutes} minute${minutes === 1 ? "" : "s"}`;
  }

  if (minutes <= 0) {
    return `${hours} hour${hours === 1 ? "" : "s"}`;
  }

  return `${hours} hour${hours === 1 ? "" : "s"} and ${minutes} minute${
    minutes === 1 ? "" : "s"
  }`;
};

const appointmentCooldown = async (req, res, next) => {
  try {
    if (!req.user || req.user.role !== USER_ROLES.PUBLIC_USER) {
      return next();
    }

    const userId = getIdString(req.user._id) || getIdString(req.userId);

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Authentication is required.",
      });
    }

    const cooldownHours = Number(process.env.APPOINTMENT_COOLDOWN_HOURS || 5);
    const cooldownMilliseconds = cooldownHours * 60 * 60 * 1000;
    const cooldownStart = new Date(Date.now() - cooldownMilliseconds);

    const recentAppointment = await Appointment.findOne({
      requestedBy: userId,
      createdAt: {
        $gte: cooldownStart,
      },
    })
      .sort({ createdAt: -1 })
      .select("_id createdAt rhu appointmentType serviceType status");

    if (!recentAppointment) {
      return next();
    }

    const nextAllowedAt = new Date(
      recentAppointment.createdAt.getTime() + cooldownMilliseconds
    );

    const remainingMilliseconds = Math.max(
      nextAllowedAt.getTime() - Date.now(),
      0
    );

    return res.status(429).json({
      success: false,
      message: `You already submitted an appointment request. Please wait ${formatRemainingTime(
        remainingMilliseconds
      )} before applying again.`,
      data: {
        cooldownHours,
        nextAllowedAt: nextAllowedAt.toISOString(),
        remainingSeconds: Math.ceil(remainingMilliseconds / 1000),
        lastAppointmentId: recentAppointment._id,
      },
    });
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  appointmentCooldown,
};