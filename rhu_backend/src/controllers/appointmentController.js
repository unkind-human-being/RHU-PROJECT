const Appointment = require("../models/Appointment");
const RHU = require("../models/RHU");
const { asyncHandler } = require("../middleware/errorMiddleware");
const { USER_ROLES } = require("../utils/constants");
const {
  notifyAppointmentSubmitted,
  notifyAppointmentAccepted,
  notifyAppointmentRejected,
} = require("../utils/appointmentNotificationHooks");
const { createNotification } = require("../services/notificationService");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);

const staffRoles = [
  USER_ROLES.IPHO_ADMIN,
  USER_ROLES.RHU_ADMIN,
];

const buildAppointmentQrPayload = (appointment) => {
  return {
    type: "rhu_appointment_qr",
    version: 1,
    token: appointment.qrToken,
    appointmentId: appointment._id.toString(),
    rhu: getIdString(appointment.rhu),
    status: appointment.status,
    appointmentType: appointment.appointmentType,
    serviceType: appointment.serviceType,
    scheduledAt: appointment.scheduledAt,
    qrExpiresAt: appointment.qrExpiresAt,
    patient: {
      firstName: appointment.patientFirstName,
      lastName: appointment.patientLastName,
      middleInitial: appointment.patientMiddleInitial,
      age: appointment.patientAge,
      sex: appointment.patientSex,
      contactNumber: appointment.contactNumber,
    },
  };
};

const getAppointmentPatientName = (appointment) => {
  const firstName = appointment.patientFirstName || "";
  const middleInitial = appointment.patientMiddleInitial || "";
  const lastName = appointment.patientLastName || "";

  const name = [firstName, middleInitial, lastName]
    .filter(Boolean)
    .join(" ")
    .trim();

  if (name) {
    return name;
  }

  if (appointment.requestedBy?.fullName) {
    return appointment.requestedBy.fullName;
  }

  return "Patient";
};

const safeNotifyAppointmentCompleted = async ({ req, appointment }) => {
  try {
    const recipient = getIdString(appointment.requestedBy);

    if (!recipient) {
      return;
    }

    await createNotification({
      recipient,
      actor: req.userId,
      type: "appointment_completed",
      title: "Consultation Completed",
      body:
        "Your RHU consultation has been completed. Please check your appointment details for notes and follow-up instructions.",
      targetRoute: "/my-appointments",
      rhu: getIdString(appointment.rhu),
      appointment: appointment._id,
      metadata: {
        appointmentId: appointment._id.toString(),
        patientName: getAppointmentPatientName(appointment),
        completedAt: appointment.completedAt || null,
        followUpDate: appointment.followUpDate || null,
      },
    });
  } catch (error) {
    console.error("Appointment completed notification failed:", error.message);
  }
};

const canAccessAppointment = (req, appointment) => {
  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return { allowed: true };
  }

  const appointmentRhuId = getIdString(appointment.rhu);

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === appointmentRhuId) {
      return { allowed: true };
    }

    return {
      allowed: false,
      message: "You can only access appointments under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.PUBLIC_USER) {
    if (getIdString(appointment.requestedBy) === req.userId.toString()) {
      return { allowed: true };
    }

    return {
      allowed: false,
      message: "You can only access your own appointment requests.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to access appointment records.",
  };
};

const buildAppointmentFilter = (req) => {
  const filter = {};

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    filter.rhu = getUserRhuId(req);
  }

  if (req.user.role === USER_ROLES.PUBLIC_USER) {
    filter.requestedBy = req.userId;
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN && req.query.rhu) {
    filter.rhu = req.query.rhu;
  }

  if (req.query.status) {
    filter.status = req.query.status;
  }

  if (req.query.serviceType) {
    filter.serviceType = req.query.serviceType;
  }

  if (req.query.appointmentType) {
    filter.appointmentType = req.query.appointmentType;
  }

  if (req.query.requestedBy) {
    filter.requestedBy = req.query.requestedBy;
  }

  if (req.query.search) {
    const searchRegex = new RegExp(req.query.search.trim(), "i");

    filter.$or = [
      { patientLastName: searchRegex },
      { patientFirstName: searchRegex },
      { contactNumber: searchRegex },
      { healthConcern: searchRegex },
      { consultationDiagnosis: searchRegex },
      { consultationNotes: searchRegex },
    ];
  }

  return filter;
};

const populateAppointment = (query) => {
  return query
    .populate("rhu", "name code municipality province phoneNumber contactNumber")
    .populate("requestedBy", "fullName email phoneNumber")
    .populate("acceptedBy", "fullName email role")
    .populate("rejectedBy", "fullName email role")
    .populate("completedBy", "fullName email role");
};

const getAppointments = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = buildAppointmentFilter(req);

  const [appointments, total] = await Promise.all([
    populateAppointment(
      Appointment.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
    ),
    Appointment.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Appointment records fetched successfully.",
    count: appointments.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: appointments.map((item) => item.toSafeObject()),
  });
});

const getMyAppointments = asyncHandler(async (req, res) => {
  req.query.requestedBy = req.userId;

  return getAppointments(req, res);
});

const getAppointmentById = asyncHandler(async (req, res) => {
  const appointment = await populateAppointment(
    Appointment.findById(req.params.id)
  );

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  const access = canAccessAppointment(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  return res.status(200).json({
    success: true,
    message: "Appointment fetched successfully.",
    data: appointment.toSafeObject(),
  });
});

const createAppointment = asyncHandler(async (req, res) => {
  const {
    rhu,
    serviceType,
    appointmentType,
    patientLastName,
    patientFirstName,
    patientMiddleInitial,
    patientAge,
    patientSex,
    religion,
    civilStatus,
    contactNumber,
    patientPhotoUrl,
    healthConcern,
    symptomsDescription,
    preferredDate,
    preferredTime,
    confirmationChecked,
  } = req.body;

  if (!rhu) {
    return res.status(400).json({
      success: false,
      message: "RHU is required.",
    });
  }

  if (!confirmationChecked) {
    return res.status(400).json({
      success: false,
      message:
        "Please confirm that this appointment request is real and the information is correct.",
    });
  }

  const existingRhu = await RHU.findById(rhu);

  if (!existingRhu || !existingRhu.isActive) {
    return res.status(400).json({
      success: false,
      message: "Selected RHU does not exist or is inactive.",
    });
  }

  if (!serviceType || !Object.values(Appointment.services).includes(serviceType)) {
    return res.status(400).json({
      success: false,
      message: "Valid service type is required.",
    });
  }

  if (!appointmentType || !Object.values(Appointment.types).includes(appointmentType)) {
    return res.status(400).json({
      success: false,
      message: "Valid appointment type is required.",
    });
  }

  const appointment = await Appointment.create({
    rhu,
    requestedBy: req.userId,
    serviceType,
    appointmentType,
    patientLastName,
    patientFirstName,
    patientMiddleInitial,
    patientAge,
    patientSex,
    religion,
    civilStatus,
    contactNumber,
    patientPhotoUrl,
    healthConcern,
    symptomsDescription,
    preferredDate: preferredDate || null,
    preferredTime,
    confirmationChecked: true,
  });

  const populatedAppointment = await populateAppointment(
    Appointment.findById(appointment._id)
  );

  await notifyAppointmentSubmitted({
    req,
    appointment: populatedAppointment,
  });

  return res.status(201).json({
    success: true,
    message: "Appointment request submitted successfully.",
    data: populatedAppointment.toSafeObject(),
  });
});

const acceptAppointment = asyncHandler(async (req, res) => {
  const {
    scheduledAt,
    scheduledEndAt,
    qrExpiresAt,
    adminNotes,
  } = req.body;

  const appointment = await Appointment.findById(req.params.id);

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  const access = canAccessAppointment(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role === USER_ROLES.PUBLIC_USER) {
    return res.status(403).json({
      success: false,
      message: "Public users cannot accept appointment requests.",
    });
  }

  if (!scheduledAt) {
    return res.status(400).json({
      success: false,
      message: "Schedule date and time are required.",
    });
  }

  const scheduleDate = new Date(scheduledAt);

  if (Number.isNaN(scheduleDate.getTime())) {
    return res.status(400).json({
      success: false,
      message: "Invalid schedule date and time.",
    });
  }

  appointment.status = Appointment.statuses.ACCEPTED;
  appointment.scheduledAt = scheduleDate;
  appointment.scheduledEndAt = scheduledEndAt ? new Date(scheduledEndAt) : null;
  appointment.acceptedBy = req.userId;
  appointment.acceptedAt = new Date();
  appointment.adminNotes = adminNotes || appointment.adminNotes || "";

  if (appointment.appointmentType === Appointment.types.WALK_IN) {
    appointment.ensureQrToken();

    const expiresDate = qrExpiresAt
      ? new Date(qrExpiresAt)
      : new Date(scheduleDate.getTime() + 2 * 60 * 60 * 1000);

    if (Number.isNaN(expiresDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: "Invalid QR expiration date.",
      });
    }

    appointment.qrExpiresAt = expiresDate;
    appointment.qrPayload = JSON.stringify(buildAppointmentQrPayload(appointment));
  }

  await appointment.save();

  const populatedAppointment = await populateAppointment(
    Appointment.findById(appointment._id)
  );

  await notifyAppointmentAccepted({
    req,
    appointment: populatedAppointment,
  });

  return res.status(200).json({
    success: true,
    message: "Appointment accepted successfully.",
    data: populatedAppointment.toSafeObject(),
  });
});

const rejectAppointment = asyncHandler(async (req, res) => {
  const { rejectionReason } = req.body;

  const appointment = await Appointment.findById(req.params.id);

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  const access = canAccessAppointment(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role === USER_ROLES.PUBLIC_USER) {
    return res.status(403).json({
      success: false,
      message: "Public users cannot reject appointment requests.",
    });
  }

  appointment.status = Appointment.statuses.REJECTED;
  appointment.rejectedBy = req.userId;
  appointment.rejectedAt = new Date();
  appointment.rejectionReason = rejectionReason || "";

  await appointment.save();

  const populatedAppointment = await populateAppointment(
    Appointment.findById(appointment._id)
  );

  await notifyAppointmentRejected({
    req,
    appointment: populatedAppointment,
  });

  return res.status(200).json({
    success: true,
    message: "Appointment rejected successfully.",
    data: populatedAppointment.toSafeObject(),
  });
});

const cancelAppointment = asyncHandler(async (req, res) => {
  const { cancellationReason } = req.body;

  const appointment = await Appointment.findById(req.params.id);

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  const access = canAccessAppointment(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (appointment.status === Appointment.statuses.COMPLETED) {
    return res.status(400).json({
      success: false,
      message: "Completed appointments cannot be cancelled.",
    });
  }

  appointment.status = Appointment.statuses.CANCELLED;
  appointment.cancelledAt = new Date();
  appointment.cancellationReason = cancellationReason || "";

  await appointment.save();

  const populatedAppointment = await populateAppointment(
    Appointment.findById(appointment._id)
  );

  return res.status(200).json({
    success: true,
    message: "Appointment cancelled successfully.",
    data: populatedAppointment.toSafeObject(),
  });
});

const completeAppointment = asyncHandler(async (req, res) => {
  const {
    consultationDiagnosis,
    consultationNotes,
    followUpInstructions,
    followUpDate,
    adminNotes,
  } = req.body;

  const appointment = await Appointment.findById(req.params.id);

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  const access = canAccessAppointment(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (!staffRoles.includes(req.user.role)) {
    return res.status(403).json({
      success: false,
      message: "Only RHU staff can complete appointments.",
    });
  }

  if (
    appointment.status === Appointment.statuses.REJECTED ||
    appointment.status === Appointment.statuses.CANCELLED ||
    appointment.status === Appointment.statuses.EXPIRED
  ) {
    return res.status(400).json({
      success: false,
      message: "Rejected, cancelled, or expired appointments cannot be completed.",
    });
  }

  if (
    appointment.status !== Appointment.statuses.ACCEPTED &&
    appointment.status !== Appointment.statuses.COMPLETED
  ) {
    return res.status(400).json({
      success: false,
      message: "Only accepted appointments can be completed.",
    });
  }

  if (followUpDate !== undefined && followUpDate !== null && followUpDate !== "") {
    const parsedFollowUpDate = new Date(followUpDate);

    if (Number.isNaN(parsedFollowUpDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: "Invalid follow-up date.",
      });
    }

    appointment.followUpDate = parsedFollowUpDate;
  }

  if (followUpDate === "" || followUpDate === null) {
    appointment.followUpDate = null;
  }

  if (typeof consultationDiagnosis === "string") {
    appointment.consultationDiagnosis = consultationDiagnosis.trim();
  }

  if (typeof consultationNotes === "string") {
    appointment.consultationNotes = consultationNotes.trim();
  }

  if (typeof followUpInstructions === "string") {
    appointment.followUpInstructions = followUpInstructions.trim();
  }

  if (typeof adminNotes === "string") {
    appointment.adminNotes = adminNotes.trim();
  }

  appointment.status = Appointment.statuses.COMPLETED;
  appointment.completedBy = req.userId;
  appointment.completedAt = appointment.completedAt || new Date();

  await appointment.save();

  const populatedAppointment = await populateAppointment(
    Appointment.findById(appointment._id)
  );

  await safeNotifyAppointmentCompleted({
    req,
    appointment: populatedAppointment,
  });

  return res.status(200).json({
    success: true,
    message: "Appointment completed successfully.",
    data: populatedAppointment.toSafeObject(),
  });
});

const getAppointmentByQrToken = asyncHandler(async (req, res) => {
  const appointment = await populateAppointment(
    Appointment.findOne({
      qrToken: req.params.token,
    })
  );

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment QR was not found.",
    });
  }

  const access = canAccessAppointment(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (
    appointment.status === Appointment.statuses.ACCEPTED &&
    appointment.isQrExpiredNow()
  ) {
    appointment.status = Appointment.statuses.EXPIRED;
    await appointment.save();
  }

  return res.status(200).json({
    success: true,
    message: "Appointment QR fetched successfully.",
    data: appointment.toSafeObject(),
  });
});

const checkInAppointment = asyncHandler(async (req, res) => {
  const appointment = await Appointment.findById(req.params.id);

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  const access = canAccessAppointment(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (!staffRoles.includes(req.user.role)) {
    return res.status(403).json({
      success: false,
      message: "Only RHU staff can check in appointment QR tickets.",
    });
  }

  if (appointment.appointmentType !== Appointment.types.WALK_IN) {
    return res.status(400).json({
      success: false,
      message: "Only walk-in appointment QR tickets can be checked in.",
    });
  }

  if (appointment.status !== Appointment.statuses.ACCEPTED) {
    return res.status(400).json({
      success: false,
      message: "Only accepted appointments can be checked in.",
    });
  }

  if (appointment.isQrExpiredNow()) {
    appointment.status = Appointment.statuses.EXPIRED;
    await appointment.save();

    return res.status(400).json({
      success: false,
      message: "This appointment QR ticket is already expired.",
    });
  }

  appointment.checkedInAt = new Date();

  await appointment.save();

  const populatedAppointment = await populateAppointment(
    Appointment.findById(appointment._id)
  );

  return res.status(200).json({
    success: true,
    message: "Appointment checked in successfully.",
    data: populatedAppointment.toSafeObject(),
  });
});

module.exports = {
  getAppointments,
  getMyAppointments,
  getAppointmentById,
  createAppointment,
  acceptAppointment,
  rejectAppointment,
  cancelAppointment,
  completeAppointment,
  getAppointmentByQrToken,
  checkInAppointment,
};