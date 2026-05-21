const Event = require("../models/Event");
const RHU = require("../models/RHU");
const Barangay = require("../models/Barangay");
const { asyncHandler } = require("../middleware/errorMiddleware");
const {
  USER_ROLES,
  EVENT_STATUS,
  AUDIENCE_SCOPE,
} = require("../utils/constants");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);
const getUserBarangayId = (req) => getIdString(req.user?.barangay);

const checkEventAccess = (req, event) => {
  if (!req.user) {
    if (
      event.status === EVENT_STATUS.OPEN &&
      event.audienceScope === AUDIENCE_SCOPE.PUBLIC
    ) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "This event is not available for public access.",
    };
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  const eventRhuId = getIdString(event.rhu);
  const eventBarangayId = getIdString(event.barangay);

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === eventRhuId) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access events under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (event.audienceScope === AUDIENCE_SCOPE.PUBLIC) {
      return {
        allowed: true,
      };
    }

    if (
      getUserRhuId(req) === eventRhuId &&
      (!eventBarangayId || getUserBarangayId(req) === eventBarangayId)
    ) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access events under your assigned barangay.",
    };
  }

  if (
    req.user.role === USER_ROLES.PUBLIC_USER &&
    event.status === EVENT_STATUS.OPEN &&
    event.audienceScope === AUDIENCE_SCOPE.PUBLIC
  ) {
    return {
      allowed: true,
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to access this event.",
  };
};

const buildPublicEventFilter = (req) => {
  const filter = {
    status: EVENT_STATUS.OPEN,
    audienceScope: AUDIENCE_SCOPE.PUBLIC,
    isDeleted: false,
  };

  if (req.query.rhu) {
    filter.rhu = req.query.rhu;
  }

  if (req.query.barangay) {
    filter.barangay = req.query.barangay;
  }

  if (req.query.type) {
    filter.type = req.query.type;
  }

  if (req.query.upcoming === "true") {
    filter.startDate = {
      $gte: new Date(),
    };
  }

  if (req.query.search) {
    const searchRegex = new RegExp(req.query.search.trim(), "i");

    filter.$or = [
      { title: searchRegex },
      { description: searchRegex },
      { locationName: searchRegex },
    ];
  }

  return filter;
};

const buildStaffEventFilter = (req) => {
  const filter = {
    isDeleted: false,
  };

  if (req.query.status) {
    filter.status = req.query.status;
  }

  if (req.query.type) {
    filter.type = req.query.type;
  }

  if (req.query.audienceScope) {
    filter.audienceScope = req.query.audienceScope;
  }

  if (req.query.upcoming === "true") {
    filter.startDate = {
      $gte: new Date(),
    };
  }

  if (req.query.startDate || req.query.endDate) {
    filter.startDate = {};

    if (req.query.startDate) {
      filter.startDate.$gte = new Date(req.query.startDate);
    }

    if (req.query.endDate) {
      filter.startDate.$lte = new Date(req.query.endDate);
    }
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    filter.rhu = getUserRhuId(req);
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    filter.rhu = getUserRhuId(req);

    filter.$or = [
      { audienceScope: AUDIENCE_SCOPE.PUBLIC },
      { barangay: getUserBarangayId(req) },
      { barangay: null },
    ];
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

    const searchConditions = [
      { title: searchRegex },
      { description: searchRegex },
      { locationName: searchRegex },
    ];

    if (filter.$or) {
      filter.$and = [
        {
          $or: filter.$or,
        },
        {
          $or: searchConditions,
        },
      ];

      delete filter.$or;
    } else {
      filter.$or = searchConditions;
    }
  }

  return filter;
};

const validateEventLocation = async ({ rhu, barangay }) => {
  if (!rhu) {
    throw new Error("RHU is required.");
  }

  const existingRHU = await RHU.findById(rhu);

  if (!existingRHU || !existingRHU.isActive) {
    throw new Error("Selected RHU does not exist or is inactive.");
  }

  if (barangay) {
    const existingBarangay = await Barangay.findById(barangay);

    if (!existingBarangay || !existingBarangay.isActive) {
      throw new Error("Selected barangay does not exist or is inactive.");
    }

    if (existingBarangay.rhu.toString() !== rhu.toString()) {
      throw new Error("Selected barangay does not belong to the selected RHU.");
    }
  }
};

const checkLocationAccess = (req, rhu, barangay = null) => {
  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === rhu.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only manage events under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (
      getUserRhuId(req) === rhu.toString() &&
      (!barangay || getUserBarangayId(req) === barangay.toString())
    ) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only manage events under your assigned barangay.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to manage events.",
  };
};

const getPublicEvents = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = buildPublicEventFilter(req);

  const [events, total] = await Promise.all([
    Event.find(filter)
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .populate("createdBy", "fullName role")
      .sort({ startDate: 1, createdAt: -1 })
      .skip(skip)
      .limit(limit),
    Event.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Public events fetched successfully.",
    count: events.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: events,
  });
});

const getEvents = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = buildStaffEventFilter(req);

  const [events, total] = await Promise.all([
    Event.find(filter)
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name code municipality province")
      .populate("createdBy", "fullName email role")
      .populate("updatedBy", "fullName email role")
      .sort({ startDate: 1, createdAt: -1 })
      .skip(skip)
      .limit(limit),
    Event.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Events fetched successfully.",
    count: events.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: events,
  });
});

const getEventById = asyncHandler(async (req, res) => {
  const event = await Event.findById(req.params.id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role")
    .populate("updatedBy", "fullName email role")
    .populate("registeredUsers.user", "fullName email role phoneNumber");

  if (!event || event.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  const access = checkEventAccess(req, {
    ...event.toObject(),
    rhu: event.rhu?._id || event.rhu,
    barangay: event.barangay?._id || event.barangay,
  });

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  return res.status(200).json({
    success: true,
    message: "Event fetched successfully.",
    data: event,
  });
});

const createEvent = asyncHandler(async (req, res) => {
  const {
    title,
    description,
    type,
    status,
    audienceScope,
    rhu,
    barangay,
    locationName,
    address,
    startDate,
    endDate,
    registrationRequired,
    registrationDeadline,
    maxParticipants,
    requirements,
    imageUrl,
    contactPerson,
    contactNumber,
  } = req.body;

  try {
    await validateEventLocation({ rhu, barangay });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }

  const access = checkLocationAccess(req, rhu, barangay);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const event = await Event.create({
    title,
    description,
    type,
    status,
    audienceScope,
    rhu,
    barangay: barangay || null,
    locationName,
    address,
    startDate,
    endDate,
    registrationRequired,
    registrationDeadline,
    maxParticipants,
    requirements,
    imageUrl,
    contactPerson,
    contactNumber,
    createdBy: req.userId,
  });

  const createdEvent = await Event.findById(event._id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role");

  return res.status(201).json({
    success: true,
    message: "Event created successfully.",
    data: createdEvent,
  });
});

const updateEvent = asyncHandler(async (req, res) => {
  const event = await Event.findById(req.params.id);

  if (!event || event.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  const access = checkEventAccess(req, event);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role === USER_ROLES.BARANGAY_HEALTH_WORKER) {
    if (event.createdBy.toString() !== req.userId.toString()) {
      return res.status(403).json({
        success: false,
        message: "Barangay health workers can only update events they created.",
      });
    }
  }

  const allowedUpdates = [
    "title",
    "description",
    "type",
    "status",
    "audienceScope",
    "barangay",
    "locationName",
    "address",
    "startDate",
    "endDate",
    "registrationRequired",
    "registrationDeadline",
    "maxParticipants",
    "requirements",
    "imageUrl",
    "contactPerson",
    "contactNumber",
    "cancellationReason",
  ];

  const updates = {};

  for (const field of allowedUpdates) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      updates[field] = req.body[field];
    }
  }

  if (updates.barangay) {
    try {
      await validateEventLocation({
        rhu: event.rhu,
        barangay: updates.barangay,
      });
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }

    const locationAccess = checkLocationAccess(req, event.rhu, updates.barangay);

    if (!locationAccess.allowed) {
      return res.status(403).json({
        success: false,
        message: locationAccess.message,
      });
    }
  }

  updates.updatedBy = req.userId;

  const updatedEvent = await Event.findByIdAndUpdate(req.params.id, updates, {
    new: true,
    runValidators: true,
  })
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role")
    .populate("updatedBy", "fullName email role");

  return res.status(200).json({
    success: true,
    message: "Event updated successfully.",
    data: updatedEvent,
  });
});

const openEvent = asyncHandler(async (req, res) => {
  const event = await Event.findById(req.params.id);

  if (!event || event.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  const access = checkEventAccess(req, event);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  event.status = EVENT_STATUS.OPEN;
  event.publishedAt = new Date();
  event.updatedBy = req.userId;
  await event.save();

  const openedEvent = await Event.findById(event._id)
    .populate("rhu", "name code municipality province")
    .populate("barangay", "name code municipality province")
    .populate("createdBy", "fullName email role")
    .populate("updatedBy", "fullName email role");

  return res.status(200).json({
    success: true,
    message: "Event opened successfully.",
    data: openedEvent,
  });
});

const closeEvent = asyncHandler(async (req, res) => {
  const event = await Event.findById(req.params.id);

  if (!event || event.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  const access = checkEventAccess(req, event);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  event.status = EVENT_STATUS.CLOSED;
  event.updatedBy = req.userId;
  await event.save();

  return res.status(200).json({
    success: true,
    message: "Event closed successfully.",
  });
});

const completeEvent = asyncHandler(async (req, res) => {
  const event = await Event.findById(req.params.id);

  if (!event || event.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  const access = checkEventAccess(req, event);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  event.status = EVENT_STATUS.COMPLETED;
  event.updatedBy = req.userId;
  await event.save();

  return res.status(200).json({
    success: true,
    message: "Event marked as completed successfully.",
  });
});

const cancelEvent = asyncHandler(async (req, res) => {
  const { cancellationReason } = req.body;

  const event = await Event.findById(req.params.id);

  if (!event || event.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  const access = checkEventAccess(req, event);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  event.status = EVENT_STATUS.CANCELLED;
  event.cancelledAt = new Date();
  event.cancellationReason = cancellationReason || "";
  event.updatedBy = req.userId;
  await event.save();

  return res.status(200).json({
    success: true,
    message: "Event cancelled successfully.",
  });
});

const deleteEvent = asyncHandler(async (req, res) => {
  const event = await Event.findById(req.params.id);

  if (!event || event.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  const access = checkEventAccess(req, event);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  event.isDeleted = true;
  event.updatedBy = req.userId;
  await event.save();

  return res.status(200).json({
    success: true,
    message: "Event deleted successfully.",
  });
});

const registerForEvent = asyncHandler(async (req, res) => {
  const event = await Event.findById(req.params.id);

  if (!event || event.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  if (!event.canAcceptRegistration()) {
    return res.status(400).json({
      success: false,
      message: "This event is not accepting registrations.",
    });
  }

  const alreadyRegistered = event.registeredUsers.some(
    (entry) =>
      entry.user.toString() === req.userId.toString() &&
      entry.status !== "cancelled"
  );

  if (alreadyRegistered) {
    return res.status(409).json({
      success: false,
      message: "You are already registered for this event.",
    });
  }

  event.registeredUsers.push({
    user: req.userId,
    fullName: req.body.fullName || req.user.fullName,
    email: req.body.email || req.user.email,
    phoneNumber: req.body.phoneNumber || req.user.phoneNumber || "",
    registeredAt: new Date(),
    status: "registered",
  });

  await event.save();

  return res.status(201).json({
    success: true,
    message: "Event registration successful.",
    data: {
      eventId: event._id,
      registeredCount: event.registeredCount,
    },
  });
});

const cancelMyRegistration = asyncHandler(async (req, res) => {
  const event = await Event.findById(req.params.id);

  if (!event || event.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  const registration = event.registeredUsers.find(
    (entry) =>
      entry.user.toString() === req.userId.toString() &&
      entry.status === "registered"
  );

  if (!registration) {
    return res.status(404).json({
      success: false,
      message: "Active registration not found for this event.",
    });
  }

  registration.status = "cancelled";
  await event.save();

  return res.status(200).json({
    success: true,
    message: "Event registration cancelled successfully.",
  });
});

const updateRegistrationStatus = asyncHandler(async (req, res) => {
  const { userId, status } = req.body;

  if (!userId || !status) {
    return res.status(400).json({
      success: false,
      message: "User ID and registration status are required.",
    });
  }

  const allowedStatuses = ["registered", "cancelled", "attended", "no_show"];

  if (!allowedStatuses.includes(status)) {
    return res.status(400).json({
      success: false,
      message: "Invalid registration status.",
    });
  }

  const event = await Event.findById(req.params.id);

  if (!event || event.isDeleted) {
    return res.status(404).json({
      success: false,
      message: "Event not found.",
    });
  }

  const access = checkEventAccess(req, event);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const registration = event.registeredUsers.find(
    (entry) => entry.user.toString() === userId.toString()
  );

  if (!registration) {
    return res.status(404).json({
      success: false,
      message: "Registration record not found.",
    });
  }

  registration.status = status;
  event.updatedBy = req.userId;
  await event.save();

  return res.status(200).json({
    success: true,
    message: "Registration status updated successfully.",
    data: {
      eventId: event._id,
      userId,
      status,
      registeredCount: event.registeredCount,
    },
  });
});

module.exports = {
  getPublicEvents,
  getEvents,
  getEventById,
  createEvent,
  updateEvent,
  openEvent,
  closeEvent,
  completeEvent,
  cancelEvent,
  deleteEvent,
  registerForEvent,
  cancelMyRegistration,
  updateRegistrationStatus,
};