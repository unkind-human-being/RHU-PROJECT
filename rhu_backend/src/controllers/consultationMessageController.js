const Appointment = require("../models/Appointment");
const ConsultationMessage = require("../models/ConsultationMessage");
const Medicine = require("../models/Medicine");
const Prescription = require("../models/Prescription");
const { asyncHandler } = require("../middleware/errorMiddleware");
const { USER_ROLES } = require("../utils/constants");
const { createNotification } = require("../services/notificationService");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);

const getPatientName = (appointment) => {
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

const buildVideoChannelName = (appointment) => {
  return `rhu_appointment_${appointment._id.toString()}`;
};

const safeNotifyPrescriptionQrSent = async ({
  req,
  appointment,
  prescription,
}) => {
  try {
    const receiverId = getIdString(appointment.requestedBy);

    if (!receiverId) {
      return;
    }

    await createNotification({
      recipient: receiverId,
      actor: req.userId,
      type: "prescription_qr_received",
      title: "Prescription QR Received",
      body: "Your prescription QR is ready. Please open your messages to view it.",
      targetRoute: "/public-messages",
      rhu: getIdString(appointment.rhu),
      appointment: appointment._id,
      prescription: prescription._id,
      metadata: {
        appointmentId: appointment._id.toString(),
        prescriptionId: prescription._id.toString(),
        doctorName: prescription.doctorName || "",
        expiresAt: prescription.expiresAt || null,
      },
    });
  } catch (error) {
    console.error("Prescription QR message notification failed:", error.message);
  }
};

const safeNotifyVideoCallStarted = async ({
  req,
  appointment,
  videoChannelName,
}) => {
  try {
    const receiverId = getIdString(appointment.requestedBy);

    if (!receiverId) {
      return;
    }

    await createNotification({
      recipient: receiverId,
      actor: req.userId,
      type: "general",
      title: "Video Consultation Started",
      body: "Your RHU online consultation video call is ready. Open your messages to join.",
      targetRoute: "/public-messages",
      rhu: getIdString(appointment.rhu),
      appointment: appointment._id,
      metadata: {
        appointmentId: appointment._id.toString(),
        videoChannelName,
      },
    });
  } catch (error) {
    console.error("Video call notification failed:", error.message);
  }
};

const buildPrescriptionQrPayload = (prescription) => {
  return {
    type: "rhu_prescription_qr",
    version: 1,
    token: prescription.qrToken,
    prescriptionId: prescription._id.toString(),
    rhu: getIdString(prescription.rhu),
    appointment: getIdString(prescription.appointment),
    status: prescription.status,
    issuedAt: prescription.issuedAt,
    expiresAt: prescription.expiresAt,
    patient: {
      firstName: prescription.patientFirstName,
      lastName: prescription.patientLastName,
      middleInitial: prescription.patientMiddleInitial,
      age: prescription.patientAge,
      sex: prescription.patientSex,
      contactNumber: prescription.contactNumber,
    },
    doctorName: prescription.doctorName,
    diagnosis: prescription.diagnosis,
    medicines: prescription.medicines.map((item) => {
      return {
        medicine: getIdString(item.medicine),
        medicineName: item.medicineName,
        genericName: item.genericName,
        strength: item.strength,
        dosageForm: item.dosageForm,
        quantity: item.quantity,
        unit: item.unit,
        instructions: item.instructions,
      };
    }),
  };
};

const populateAppointment = (query) => {
  return query
    .populate("rhu", "name code municipality province")
    .populate("requestedBy", "fullName email phoneNumber");
};

const populateMessage = (query) => {
  return query
    .populate("sentBy", "fullName email role")
    .populate("receiver", "fullName email role")
    .populate("prescription");
};

const canAccessAppointmentMessages = (req, appointment) => {
  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === getIdString(appointment.rhu)) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message:
        "You can only access consultation messages under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.PUBLIC_USER) {
    if (getIdString(appointment.requestedBy) === req.userId.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access your own consultation messages.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to access consultation messages.",
  };
};

const canRHUAdminSendToAppointment = (req, appointment) => {
  if (req.user.role !== USER_ROLES.RHU_ADMIN) {
    return {
      allowed: false,
      message: "Only RHU Admin can send consultation messages.",
    };
  }

  if (getUserRhuId(req) !== getIdString(appointment.rhu)) {
    return {
      allowed: false,
      message: "RHU Admin can only message patients under their assigned RHU.",
    };
  }

  return {
    allowed: true,
  };
};

const getAppointmentOr404 = async (appointmentId) => {
  return populateAppointment(Appointment.findById(appointmentId));
};

const getAppointmentMessages = asyncHandler(async (req, res) => {
  const appointment = await getAppointmentOr404(req.params.appointmentId);

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  const access = canAccessAppointmentMessages(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const messages = await populateMessage(
    ConsultationMessage.find({
      appointment: appointment._id,
    }).sort({ sentAt: 1, createdAt: 1 })
  );

  if (req.user.role === USER_ROLES.PUBLIC_USER) {
    await ConsultationMessage.updateMany(
      {
        appointment: appointment._id,
        receiver: req.userId,
        readAt: null,
      },
      {
        readAt: new Date(),
      }
    );
  }

  return res.status(200).json({
    success: true,
    message: "Consultation messages fetched successfully.",
    appointment: appointment.toSafeObject
      ? appointment.toSafeObject()
      : appointment,
    count: messages.length,
    data: messages.map((message) => message.toSafeObject()),
  });
});

const sendTextMessage = asyncHandler(async (req, res) => {
  const { body } = req.body;

  if (!body || !body.trim()) {
    return res.status(400).json({
      success: false,
      message: "Message body is required.",
    });
  }

  const appointment = await getAppointmentOr404(req.params.appointmentId);

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  const access = canRHUAdminSendToAppointment(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (appointment.status !== Appointment.statuses.ACCEPTED) {
    return res.status(400).json({
      success: false,
      message: "Only accepted appointments can receive consultation messages.",
    });
  }

  const receiverId = getIdString(appointment.requestedBy);

  if (!receiverId) {
    return res.status(400).json({
      success: false,
      message: "Appointment has no patient user account.",
    });
  }

  const message = await ConsultationMessage.create({
    appointment: appointment._id,
    rhu: appointment.rhu,
    sentBy: req.userId,
    receiver: receiverId,
    messageType: ConsultationMessage.types.TEXT,
    body: body.trim(),
  });

  const populatedMessage = await populateMessage(
    ConsultationMessage.findById(message._id)
  );

  return res.status(201).json({
    success: true,
    message: "Message sent successfully.",
    data: populatedMessage.toSafeObject(),
  });
});

const sendVideoCallMessage = asyncHandler(async (req, res) => {
  const { body, videoChannelName } = req.body;

  const appointment = await getAppointmentOr404(req.params.appointmentId);

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  const access = canRHUAdminSendToAppointment(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (appointment.status !== Appointment.statuses.ACCEPTED) {
    return res.status(400).json({
      success: false,
      message: "Only accepted appointments can receive video call invites.",
    });
  }

  if (appointment.appointmentType !== Appointment.types.ONLINE) {
    return res.status(400).json({
      success: false,
      message: "Video call is only available for online consultations.",
    });
  }

  const receiverId = getIdString(appointment.requestedBy);

  if (!receiverId) {
    return res.status(400).json({
      success: false,
      message: "Appointment has no patient user account.",
    });
  }

  const channelName =
    videoChannelName && videoChannelName.trim()
      ? videoChannelName.trim()
      : buildVideoChannelName(appointment);

  const message = await ConsultationMessage.create({
    appointment: appointment._id,
    rhu: appointment.rhu,
    sentBy: req.userId,
    receiver: receiverId,
    messageType: ConsultationMessage.types.VIDEO_CALL,
    body:
      body ||
      `Video consultation started for ${getPatientName(appointment)}. Tap Join Video Call to enter.`,
    videoChannelName: channelName,
  });

  await safeNotifyVideoCallStarted({
    req,
    appointment,
    videoChannelName: channelName,
  });

  const populatedMessage = await populateMessage(
    ConsultationMessage.findById(message._id)
  );

  return res.status(201).json({
    success: true,
    message: "Video call invite sent successfully.",
    data: populatedMessage.toSafeObject(),
  });
});

const sendPrescriptionQrMessage = asyncHandler(async (req, res) => {
  const {
    diagnosis,
    doctorName,
    medicines,
    expiresAt,
    messageBody,
  } = req.body;

  const appointment = await getAppointmentOr404(req.params.appointmentId);

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  const access = canRHUAdminSendToAppointment(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (appointment.status !== Appointment.statuses.ACCEPTED) {
    return res.status(400).json({
      success: false,
      message:
        "Only accepted appointments can receive prescription QR messages.",
    });
  }

  if (!Array.isArray(medicines) || medicines.length === 0) {
    return res.status(400).json({
      success: false,
      message: "At least one prescribed medicine is required.",
    });
  }

  const normalizedMedicines = [];

  for (const item of medicines) {
    if (!item.medicineName && !item.medicine) {
      return res.status(400).json({
        success: false,
        message: "Each medicine must have a medicine name.",
      });
    }

    let medicineDoc = null;

    if (item.medicine) {
      medicineDoc = await Medicine.findById(item.medicine);

      if (!medicineDoc) {
        return res.status(400).json({
          success: false,
          message: "One selected medicine does not exist.",
        });
      }

      if (getIdString(medicineDoc.rhu) !== getIdString(appointment.rhu)) {
        return res.status(403).json({
          success: false,
          message:
            "You can only prescribe medicines under this appointment RHU.",
        });
      }
    }

    normalizedMedicines.push({
      medicine: item.medicine || null,
      medicineName: item.medicineName || medicineDoc?.name || "",
      genericName: item.genericName || medicineDoc?.genericName || "",
      strength: item.strength || medicineDoc?.strength || "",
      dosageForm: item.dosageForm || medicineDoc?.dosageForm || "",
      quantity: Number(item.quantity || 1),
      unit: item.unit || medicineDoc?.unit || "pcs",
      instructions: item.instructions || "",
    });
  }

  const expirationDate = expiresAt
    ? new Date(expiresAt)
    : new Date(Date.now() + 24 * 60 * 60 * 1000);

  if (Number.isNaN(expirationDate.getTime())) {
    return res.status(400).json({
      success: false,
      message: "Invalid prescription QR expiration date.",
    });
  }

  const prescription = await Prescription.create({
    rhu: appointment.rhu,
    appointment: appointment._id,
    patientUser: appointment.requestedBy,
    patientLastName: appointment.patientLastName,
    patientFirstName: appointment.patientFirstName,
    patientMiddleInitial: appointment.patientMiddleInitial,
    patientAge: appointment.patientAge,
    patientSex: appointment.patientSex,
    contactNumber: appointment.contactNumber,
    diagnosis: diagnosis || appointment.healthConcern || "",
    doctorName: doctorName || "DR. Alnidzfar-nadz D. Jericho",
    prescribedBy: req.userId,
    medicines: normalizedMedicines,
    expiresAt: expirationDate,
  });

  prescription.qrPayload = JSON.stringify(
    buildPrescriptionQrPayload(prescription)
  );

  await prescription.save();

  const receiverId = getIdString(appointment.requestedBy);

  if (!receiverId) {
    return res.status(400).json({
      success: false,
      message: "Appointment has no patient user account.",
    });
  }

  const message = await ConsultationMessage.create({
    appointment: appointment._id,
    rhu: appointment.rhu,
    sentBy: req.userId,
    receiver: receiverId,
    messageType: ConsultationMessage.types.PRESCRIPTION_QR,
    body:
      messageBody ||
      "Your prescription QR is ready. Please show this QR at the pharmacy.",
    prescription: prescription._id,
    prescriptionQrPayload: prescription.qrPayload,
  });

  await safeNotifyPrescriptionQrSent({
    req,
    appointment,
    prescription,
  });

  const [populatedMessage, populatedPrescription] = await Promise.all([
    populateMessage(ConsultationMessage.findById(message._id)),
    Prescription.findById(prescription._id)
      .populate("rhu", "name code municipality province")
      .populate("patientUser", "fullName email phoneNumber")
      .populate("prescribedBy", "fullName email role")
      .populate("medicines.medicine", "name genericName strength unit category"),
  ]);

  return res.status(201).json({
    success: true,
    message: "Prescription QR message sent successfully.",
    data: {
      message: populatedMessage.toSafeObject(),
      prescription: populatedPrescription.toSafeObject
        ? populatedPrescription.toSafeObject()
        : populatedPrescription,
    },
  });
});

const markMessageAsRead = asyncHandler(async (req, res) => {
  const message = await ConsultationMessage.findById(req.params.id);

  if (!message) {
    return res.status(404).json({
      success: false,
      message: "Message not found.",
    });
  }

  if (getIdString(message.receiver) !== req.userId.toString()) {
    return res.status(403).json({
      success: false,
      message: "You can only mark your own messages as read.",
    });
  }

  message.readAt = message.readAt || new Date();

  await message.save();

  const populatedMessage = await populateMessage(
    ConsultationMessage.findById(message._id)
  );

  return res.status(200).json({
    success: true,
    message: "Message marked as read.",
    data: populatedMessage.toSafeObject(),
  });
});

module.exports = {
  getAppointmentMessages,
  sendTextMessage,
  sendVideoCallMessage,
  sendPrescriptionQrMessage,
  markMessageAsRead,
};