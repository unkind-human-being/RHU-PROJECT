const Notification = require("../models/Notification");
const { createNotification } = require("../services/notificationService");
const { asyncHandler } = require("../middleware/errorMiddleware");
const { USER_ROLES } = require("../utils/constants");

const getMyNotifications = asyncHandler(async (req, res) => {
  const page = Math.max(Number(req.query.page) || 1, 1);
  const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 100);
  const skip = (page - 1) * limit;
  const unreadOnly = req.query.unreadOnly === "true";

  const filter = {
    recipient: req.userId,
  };

  if (unreadOnly) {
    filter.isRead = false;
  }

  const [notifications, total, unreadCount] = await Promise.all([
    Notification.find(filter)
      .sort({
        createdAt: -1,
      })
      .skip(skip)
      .limit(limit)
      .populate("actor", "fullName email role")
      .populate("rhu", "name code municipality province")
      .populate("barangay", "name municipality province")
      .populate("appointment", "status appointmentType serviceType scheduledAt")
      .populate("event", "title name status")
      .populate("survey", "title name status"),

    Notification.countDocuments(filter),

    Notification.countDocuments({
      recipient: req.userId,
      isRead: false,
    }),
  ]);

  return res.status(200).json({
    success: true,
    message: "Notifications fetched successfully.",
    page,
    limit,
    total,
    unreadCount,
    data: notifications.map((notification) => notification.toSafeObject()),
  });
});

const getUnreadNotificationCount = asyncHandler(async (req, res) => {
  const unreadCount = await Notification.countDocuments({
    recipient: req.userId,
    isRead: false,
  });

  return res.status(200).json({
    success: true,
    message: "Unread notification count fetched successfully.",
    unreadCount,
  });
});

const markNotificationAsRead = asyncHandler(async (req, res) => {
  const notification = await Notification.findOne({
    _id: req.params.id,
    recipient: req.userId,
  });

  if (!notification) {
    return res.status(404).json({
      success: false,
      message: "Notification not found.",
    });
  }

  await notification.markAsRead();

  return res.status(200).json({
    success: true,
    message: "Notification marked as read.",
    data: notification.toSafeObject(),
  });
});

const markAllNotificationsAsRead = asyncHandler(async (req, res) => {
  const result = await Notification.updateMany(
    {
      recipient: req.userId,
      isRead: false,
    },
    {
      $set: {
        isRead: true,
        readAt: new Date(),
      },
    }
  );

  return res.status(200).json({
    success: true,
    message: "All notifications marked as read.",
    modifiedCount: result.modifiedCount || 0,
  });
});

const createTestNotification = asyncHandler(async (req, res) => {
  if (
    req.user.role !== USER_ROLES.IPHO_ADMIN &&
    req.user.role !== USER_ROLES.RHU_ADMIN
  ) {
    return res.status(403).json({
      success: false,
      message: "Only admin users can create test notifications.",
    });
  }

  const recipient = req.body.recipient || req.userId;

  const notification = await createNotification({
    recipient,
    actor: req.userId,
    type: req.body.type || Notification.types.GENERAL,
    title: req.body.title || "Test notification",
    body: req.body.body || "This is a test notification.",
    targetRoute: req.body.targetRoute || "",
    rhu: req.body.rhu || req.user?.rhu || null,
    barangay: req.body.barangay || null,
    appointment: req.body.appointment || null,
    prescription: req.body.prescription || null,
    event: req.body.event || null,
    survey: req.body.survey || null,
    metadata: req.body.metadata || {},
  });

  return res.status(201).json({
    success: true,
    message: "Test notification created successfully.",
    data: notification.toSafeObject(),
  });
});

module.exports = {
  getMyNotifications,
  getUnreadNotificationCount,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  createTestNotification,
};