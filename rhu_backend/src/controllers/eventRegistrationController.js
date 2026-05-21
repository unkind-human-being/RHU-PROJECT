const Event = require("../models/Event");
const EventRegistration = require("../models/EventRegistration");
const { asyncHandler } = require("../middleware/errorMiddleware");
const { USER_ROLES } = require("../utils/constants");

const {
  createNotification,
  notifyRhuAdmins,
} = require("../services/notificationService");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);

const populateEvent = (query) => {
  return query.populate("rhu", "name code municipality province contactNumber");
};

const populateRegistration = (query) => {
  return query
    .populate("event", "title name startDate eventDate scheduledAt status")
    .populate("rhu", "name code municipality province contactNumber")
    .populate("user", "fullName email phoneNumber")
    .populate("updatedBy", "fullName email role");
};

const getEventRhuId = (event) => {
  return getIdString(event.rhu);
};

const getEventTitle = (event) => {
  return event.title || event.name || "RHU event";
};

const isEventOpenForRegistration = (event) => {
  const status = (event.status || "").toString().toLowerCase();

  if (!status) {
    return true;
  }

  return status === "open" || status === "published" || status === "active";
};

const canManageEventRegistration = (req, event) => {
  if (!req.user) {
    return {
      allowed: false,
      message: "You are not authorized to manage event registrations.",
    };
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === getEventRhuId(event)) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message:
        "RHU Admin can only manage event registrations under their assigned RHU.",
    };
  }

  return {
    allowed: false,
    message: "Only RHU Admin or IPHO Admin can manage event registrations.",
  };
};

const safeCreateEventNotifications = async ({
  req,
  event,
  registration,
  attendeeName,
}) => {
  try {
    const eventTitle = getEventTitle(event);
    const eventRhuId = getEventRhuId(event);

    await createNotification({
      recipient: req.userId,
      actor: req.userId,
      type: "event_registration_confirmed",
      title: "Event Registration Confirmed",
      body: `You are registered for ${eventTitle}.`,
      targetRoute: "/public-activity-history",
      rhu: eventRhuId,
      event: event._id,
      metadata: {
        registrationId: registration._id.toString(),
        eventTitle,
      },
    });

    await notifyRhuAdmins({
      rhu: eventRhuId,
      actor: req.userId,
      type: "event_registration_received",
      title: "New Event Registration",
      body: `${attendeeName} registered for ${eventTitle}.`,
      targetRoute: "/event-registrants",
      event: event._id,
      metadata: {
        registrationId: registration._id.toString(),
        eventTitle,
        attendeeName,
      },
    });
  } catch (error) {
    console.error("Event notification creation failed:", error.message);
  }
};

const registerForEvent = asyncHandler(async (req, res) => {
  const event = await populateEvent(Event.findById(req.params.eventId));

  if (!event) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  if (!isEventOpenForRegistration(event)) {
    return res.status(400).json({
      success: false,
      message: "This event is not open for registration.",
    });
  }

  const attendeeName = (req.body.attendeeName || req.user?.fullName || "")
    .toString()
    .trim();

  if (!attendeeName) {
    return res.status(400).json({
      success: false,
      message: "Attendee name is required.",
    });
  }

  const registration = await EventRegistration.findOneAndUpdate(
    {
      event: event._id,
      user: req.userId,
    },
    {
      $set: {
        rhu: getEventRhuId(event),
        attendeeName,
        contactNumber: req.body.contactNumber || req.user?.phoneNumber || "",
        email: req.body.email || req.user?.email || "",
        notes: req.body.notes || "",
        status: EventRegistration.statuses.REGISTERED,
        updatedBy: req.userId,
      },
      $setOnInsert: {
        registeredAt: new Date(),
      },
    },
    {
      new: true,
      upsert: true,
      runValidators: true,
    }
  );

  await safeCreateEventNotifications({
    req,
    event,
    registration,
    attendeeName,
  });

  const populatedRegistration = await populateRegistration(
    EventRegistration.findById(registration._id)
  );

  return res.status(201).json({
    success: true,
    message: "Event registration submitted successfully.",
    data: populatedRegistration.toSafeObject(),
  });
});

const getMyEventRegistrations = asyncHandler(async (req, res) => {
  const registrations = await populateRegistration(
    EventRegistration.find({
      user: req.userId,
    }).sort({ registeredAt: -1, createdAt: -1 })
  );

  return res.status(200).json({
    success: true,
    message: "My event registrations fetched successfully.",
    count: registrations.length,
    data: registrations.map((registration) => registration.toSafeObject()),
  });
});

const getEventRegistrations = asyncHandler(async (req, res) => {
  const event = await populateEvent(Event.findById(req.params.eventId));

  if (!event) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  const access = canManageEventRegistration(req, event);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const registrations = await populateRegistration(
    EventRegistration.find({
      event: event._id,
    }).sort({ registeredAt: -1, createdAt: -1 })
  );

  return res.status(200).json({
    success: true,
    message: "Event registrations fetched successfully.",
    event: event.toSafeObject ? event.toSafeObject() : event,
    count: registrations.length,
    data: registrations.map((registration) => registration.toSafeObject()),
  });
});

const updateEventRegistrationStatus = asyncHandler(async (req, res) => {
  const { status } = req.body;

  if (!Object.values(EventRegistration.statuses).includes(status)) {
    return res.status(400).json({
      success: false,
      message: "Invalid event registration status.",
    });
  }

  const registration = await populateRegistration(
    EventRegistration.findById(req.params.id)
  );

  if (!registration) {
    return res.status(404).json({
      success: false,
      message: "Event registration not found.",
    });
  }

  const event = await Event.findById(registration.event?._id || registration.event);

  if (!event) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  const access = canManageEventRegistration(req, event);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  registration.status = status;
  registration.updatedBy = req.userId;

  if (status === EventRegistration.statuses.ATTENDED) {
    registration.checkedInAt = registration.checkedInAt || new Date();
  }

  await registration.save();

  const updatedRegistration = await populateRegistration(
    EventRegistration.findById(registration._id)
  );

  return res.status(200).json({
    success: true,
    message: "Event registration status updated successfully.",
    data: updatedRegistration.toSafeObject(),
  });
});

module.exports = {
  registerForEvent,
  getMyEventRegistrations,
  getEventRegistrations,
  updateEventRegistrationStatus,
};