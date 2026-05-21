const {
  createNotification,
  notifyRhuAdmins,
} = require("../services/notificationService");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getAppointmentPublicUserId = (appointment) => {
  return (
    getIdString(appointment.requestedBy) ||
    getIdString(appointment.publicUser) ||
    getIdString(appointment.patientUser) ||
    getIdString(appointment.user)
  );
};

const getAppointmentRhuId = (appointment) => {
  return getIdString(appointment.rhu);
};

const getAppointmentTitle = (appointment) => {
  const serviceType = (appointment.serviceType || "appointment")
    .toString()
    .replace(/_/g, " ");

  return serviceType.charAt(0).toUpperCase() + serviceType.slice(1);
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

  if (appointment.publicUser?.fullName) {
    return appointment.publicUser.fullName;
  }

  if (appointment.patientUser?.fullName) {
    return appointment.patientUser.fullName;
  }

  if (appointment.user?.fullName) {
    return appointment.user.fullName;
  }

  return "A public user";
};

const getAppointmentTargetForPublic = (appointment) => {
  if (appointment.appointmentType === "walk_in") {
    return "/my-appointments";
  }

  return "/my-appointments";
};

const getAppointmentTargetForAdmin = () => {
  return "/manage-appointments";
};

const notifyAppointmentSubmitted = async ({ req, appointment }) => {
  try {
    const rhuId = getAppointmentRhuId(appointment);
    const patientName = getAppointmentPatientName(appointment);
    const appointmentTitle = getAppointmentTitle(appointment);

    await notifyRhuAdmins({
      rhu: rhuId,
      actor: req.userId,
      type: "appointment_submitted",
      title: "New Appointment Request",
      body: `${patientName} submitted a ${appointmentTitle} request.`,
      targetRoute: getAppointmentTargetForAdmin(),
      appointment: appointment._id,
      metadata: {
        appointmentId: appointment._id.toString(),
        patientName,
        appointmentType: appointment.appointmentType || "",
        serviceType: appointment.serviceType || "",
      },
    });
  } catch (error) {
    console.error("Appointment submitted notification failed:", error.message);
  }
};

const notifyAppointmentAccepted = async ({ req, appointment }) => {
  try {
    const recipient = getAppointmentPublicUserId(appointment);

    if (!recipient) {
      return;
    }

    const appointmentTitle = getAppointmentTitle(appointment);

    await createNotification({
      recipient,
      actor: req.userId,
      type: "appointment_accepted",
      title: "Appointment Accepted",
      body:
        `Your ${appointmentTitle} request has been accepted. ` +
        "Please check your appointment details.",
      targetRoute: getAppointmentTargetForPublic(appointment),
      rhu: getAppointmentRhuId(appointment),
      appointment: appointment._id,
      metadata: {
        appointmentId: appointment._id.toString(),
        appointmentType: appointment.appointmentType || "",
        serviceType: appointment.serviceType || "",
        scheduledAt: appointment.scheduledAt || null,
      },
    });

    if (appointment.appointmentType === "walk_in") {
      await createNotification({
        recipient,
        actor: req.userId,
        type: "walk_in_qr_generated",
        title: "Walk-in QR Ticket Ready",
        body:
          "Your walk-in QR ticket has been generated. " +
          "Show it when you arrive at the RHU.",
        targetRoute: "/my-appointments",
        rhu: getAppointmentRhuId(appointment),
        appointment: appointment._id,
        metadata: {
          appointmentId: appointment._id.toString(),
          qrExpiresAt: appointment.qrExpiresAt || null,
        },
      });
    }
  } catch (error) {
    console.error("Appointment accepted notification failed:", error.message);
  }
};

const notifyAppointmentRejected = async ({ req, appointment }) => {
  try {
    const recipient = getAppointmentPublicUserId(appointment);

    if (!recipient) {
      return;
    }

    const appointmentTitle = getAppointmentTitle(appointment);

    await createNotification({
      recipient,
      actor: req.userId,
      type: "appointment_rejected",
      title: "Appointment Not Approved",
      body:
        `Your ${appointmentTitle} request was not approved. ` +
        "Please check your appointment details.",
      targetRoute: "/my-appointments",
      rhu: getAppointmentRhuId(appointment),
      appointment: appointment._id,
      metadata: {
        appointmentId: appointment._id.toString(),
        appointmentType: appointment.appointmentType || "",
        serviceType: appointment.serviceType || "",
        adminNotes: appointment.adminNotes || appointment.rejectionReason || "",
      },
    });
  } catch (error) {
    console.error("Appointment rejected notification failed:", error.message);
  }
};

module.exports = {
  notifyAppointmentSubmitted,
  notifyAppointmentAccepted,
  notifyAppointmentRejected,
};