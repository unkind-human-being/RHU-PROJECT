const Notification = require("../models/Notification");
const User = require("../models/User");
const { USER_ROLES } = require("../utils/constants");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const compactPayload = (payload) => {
  const clean = {};

  for (const [key, value] of Object.entries(payload || {})) {
    if (value !== undefined && value !== null && value !== "") {
      clean[key] = value;
    }
  }

  return clean;
};

const createNotification = async (payload) => {
  if (!payload || !payload.recipient) {
    return null;
  }

  const notification = await Notification.create(
    compactPayload({
      recipient: payload.recipient,
      actor: payload.actor || null,
      type: payload.type || Notification.types.GENERAL,
      title: payload.title || "New notification",
      body: payload.body || "",
      targetRoute: payload.targetRoute || "",
      rhu: payload.rhu || null,
      barangay: payload.barangay || null,
      appointment: payload.appointment || null,
      prescription: payload.prescription || null,
      event: payload.event || null,
      survey: payload.survey || null,
      metadata: payload.metadata || {},
    })
  );

  return notification;
};

const createNotificationsForUsers = async (users, payload) => {
  const userIds = (users || [])
    .map((user) => getIdString(user))
    .filter(Boolean);

  if (userIds.length === 0) {
    return [];
  }

  const documents = userIds.map((userId) => {
    return compactPayload({
      recipient: userId,
      actor: payload.actor || null,
      type: payload.type || Notification.types.GENERAL,
      title: payload.title || "New notification",
      body: payload.body || "",
      targetRoute: payload.targetRoute || "",
      rhu: payload.rhu || null,
      barangay: payload.barangay || null,
      appointment: payload.appointment || null,
      prescription: payload.prescription || null,
      event: payload.event || null,
      survey: payload.survey || null,
      metadata: payload.metadata || {},
    });
  });

  return Notification.insertMany(documents, {
    ordered: false,
  });
};

const findRhuAdmins = async (rhuId) => {
  if (!rhuId) {
    return [];
  }

  return User.find({
    role: USER_ROLES.RHU_ADMIN,
    rhu: rhuId,
    isActive: true,
  }).select("_id");
};

const findIphoAdmins = async () => {
  return User.find({
    role: USER_ROLES.IPHO_ADMIN,
    isActive: true,
  }).select("_id");
};

const notifyRhuAdmins = async ({
  rhu,
  actor = null,
  type,
  title,
  body = "",
  targetRoute = "",
  barangay = null,
  appointment = null,
  prescription = null,
  event = null,
  survey = null,
  metadata = {},
}) => {
  const admins = await findRhuAdmins(rhu);

  return createNotificationsForUsers(admins, {
    actor,
    type,
    title,
    body,
    targetRoute,
    rhu,
    barangay,
    appointment,
    prescription,
    event,
    survey,
    metadata,
  });
};

const notifyIphoAdmins = async ({
  actor = null,
  type,
  title,
  body = "",
  targetRoute = "",
  rhu = null,
  barangay = null,
  appointment = null,
  prescription = null,
  event = null,
  survey = null,
  metadata = {},
}) => {
  const admins = await findIphoAdmins();

  return createNotificationsForUsers(admins, {
    actor,
    type,
    title,
    body,
    targetRoute,
    rhu,
    barangay,
    appointment,
    prescription,
    event,
    survey,
    metadata,
  });
};

module.exports = {
  createNotification,
  createNotificationsForUsers,
  notifyRhuAdmins,
  notifyIphoAdmins,
};