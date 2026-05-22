const { RtcTokenBuilder, RtcRole } = require("agora-access-token");

const Appointment = require("../models/Appointment");
const VideoCallLog = require("../models/VideoCallLog");
const User = require("../models/User");
const { asyncHandler } = require("../middleware/errorMiddleware");
const { USER_ROLES } = require("../utils/constants");
const { getFirebaseMessaging } = require("../config/firebaseAdmin");

const getIdString = (value) => {
  if (!value) return null;
  if (value._id) return value._id.toString();
  return value.toString();
};

const getUserRhuId = (req) => getIdString(req.user?.rhu);

const buildNumericUidFromUserId = (userId) => {
  const text = userId.toString();

  let hash = 0;

  for (let index = 0; index < text.length; index += 1) {
    hash = (hash * 31 + text.charCodeAt(index)) % 2147483647;
  }

  return hash <= 0 ? 1 : hash;
};

const validateChannelName = (channelName) => {
  if (!channelName || typeof channelName !== "string") {
    return false;
  }

  if (channelName.length > 64) {
    return false;
  }

  return /^[a-zA-Z0-9_-]+$/.test(channelName);
};

const getAppointmentIdFromChannel = (channelName) => {
  const channelPrefix = "rhu_appointment_";

  if (!channelName.startsWith(channelPrefix)) {
    return null;
  }

  return channelName.replace(channelPrefix, "");
};

const populateCallLog = (query) => {
  return query
    .populate(
      "appointment",
      "serviceType appointmentType status scheduledAt patientFirstName patientLastName requestedBy"
    )
    .populate("rhu", "name code municipality province")
    .populate("startedBy", "fullName email role")
    .populate("receiver", "fullName email role phoneNumber")
    .populate("endedBy", "fullName email role")
    .populate("participants.user", "fullName email role");
};

const canJoinAppointmentVideo = (req, appointment) => {
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
      message: "You can only join video calls under your assigned RHU.",
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
      message: "You can only join your own appointment video call.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to join this video call.",
  };
};

const canViewAppointmentCallLogs = (req, appointment) => {
  return canJoinAppointmentVideo(req, appointment);
};

const getAppointmentForChannel = async (req, channelName) => {
  if (!validateChannelName(channelName)) {
    return {
      statusCode: 400,
      error: {
        success: false,
        message:
          "Valid channelName is required. Use only letters, numbers, underscore, or dash. Max 64 characters.",
      },
    };
  }

  const appointmentId = getAppointmentIdFromChannel(channelName);

  if (!appointmentId) {
    return {
      statusCode: 400,
      error: {
        success: false,
        message: "Invalid RHU video channel name.",
      },
    };
  }

  const appointment = await Appointment.findById(appointmentId);

  if (!appointment) {
    return {
      statusCode: 404,
      error: {
        success: false,
        message: "Appointment not found for this video channel.",
      },
    };
  }

  if (appointment.status !== Appointment.statuses.ACCEPTED) {
    return {
      statusCode: 400,
      error: {
        success: false,
        message: "Only accepted appointments can start or join video calls.",
      },
    };
  }

  if (appointment.appointmentType !== Appointment.types.ONLINE) {
    return {
      statusCode: 400,
      error: {
        success: false,
        message: "Video call is only available for online consultations.",
      },
    };
  }

  const access = canJoinAppointmentVideo(req, appointment);

  if (!access.allowed) {
    return {
      statusCode: 403,
      error: {
        success: false,
        message: access.message,
      },
    };
  }

  return {
    appointment,
  };
};

const addParticipantToCallLog = async ({ callLog, req, uid }) => {
  const userId = req.userId.toString();

  const existingParticipant = callLog.participants.find((participant) => {
    return getIdString(participant.user) === userId;
  });

  if (!existingParticipant) {
    callLog.participants.push({
      user: req.userId,
      role: req.user.role,
      uid,
      joinedAt: new Date(),
    });

    await callLog.save();
  }

  return callLog;
};

const getOrCreateActiveCallLog = async ({
  req,
  appointment,
  channelName,
  uid,
}) => {
  let callLog = await VideoCallLog.findOne({
    appointment: appointment._id,
    channelName,
    status: {
      $in: [VideoCallLog.statuses.RINGING, VideoCallLog.statuses.ACTIVE],
    },
  }).sort({
    startedAt: -1,
  });

  if (!callLog) {
    callLog = await VideoCallLog.create({
      appointment: appointment._id,
      rhu: appointment.rhu,
      channelName,
      startedBy: req.userId,
      startedAt: new Date(),
      status: VideoCallLog.statuses.ACTIVE,
      participants: [],
    });
  }

  if (callLog.status === VideoCallLog.statuses.RINGING) {
    callLog.status = VideoCallLog.statuses.ACTIVE;
    callLog.acceptedAt = callLog.acceptedAt || new Date();
    await callLog.save();
  }

  await addParticipantToCallLog({
    callLog,
    req,
    uid,
  });

  return callLog;
};

const buildCallPayload = (callLog) => {
  return {
    type: "incoming_call",
    callId: callLog._id.toString(),
    appointmentId: callLog.appointment.toString(),
    channelName: callLog.channelName,
    callerName: callLog.callerName || "RHU Admin",
    rhuName: callLog.rhuName || "RHU Video Consultation",
  };
};

const sendIncomingCallFcm = async ({ receiver, payload }) => {
  const messaging = getFirebaseMessaging();

  if (!messaging) {
    return {
      sent: false,
      error: "Firebase messaging is not configured.",
    };
  }

  const tokens = (receiver.fcmTokens || [])
    .map((item) => item.token)
    .filter(Boolean);

  if (tokens.length === 0) {
    return {
      sent: false,
      error: "Receiver has no FCM token.",
    };
  }

  const dataPayload = Object.fromEntries(
    Object.entries(payload).map(([key, value]) => [key, String(value)])
  );

  try {
    let response;

    if (typeof messaging.sendEachForMulticast === "function") {
      response = await messaging.sendEachForMulticast({
        tokens,
        data: dataPayload,
        android: {
          priority: "high",
        },
      });
    } else {
      response = await messaging.sendMulticast({
        tokens,
        data: dataPayload,
        android: {
          priority: "high",
        },
      });
    }

    return {
      sent: response.successCount > 0,
      error:
        response.failureCount > 0
          ? `${response.failureCount} FCM token(s) failed.`
          : "",
    };
  } catch (error) {
    return {
      sent: false,
      error: error.message,
    };
  }
};

const getAgoraToken = asyncHandler(async (req, res) => {
  const { channelName } = req.query;

  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;

  if (!appId || !appCertificate) {
    return res.status(500).json({
      success: false,
      message:
        "Agora configuration is missing. Please set AGORA_APP_ID and AGORA_APP_CERTIFICATE in .env.",
    });
  }

  const result = await getAppointmentForChannel(req, channelName);

  if (result.error) {
    return res.status(result.statusCode).json(result.error);
  }

  const appointment = result.appointment;

  const uid = buildNumericUidFromUserId(req.userId);
  const role = RtcRole.PUBLISHER;

  const expireSeconds = Number(process.env.AGORA_TOKEN_EXPIRE_SECONDS || 3600);
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpireTimestamp = currentTimestamp + expireSeconds;

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    uid,
    role,
    privilegeExpireTimestamp
  );

  const callLog = await getOrCreateActiveCallLog({
    req,
    appointment,
    channelName,
    uid,
  });

  return res.status(200).json({
    success: true,
    message: "Agora token generated successfully.",
    data: {
      appId,
      token,
      channelName,
      uid,
      callLogId: callLog._id,
      expiresIn: expireSeconds,
      expiresAt: new Date(privilegeExpireTimestamp * 1000).toISOString(),
    },
  });
});

const markVideoCallJoined = asyncHandler(async (req, res) => {
  const { channelName, uid } = req.body;

  const result = await getAppointmentForChannel(req, channelName);

  if (result.error) {
    return res.status(result.statusCode).json(result.error);
  }

  const appointment = result.appointment;
  const safeUid = Number(uid || buildNumericUidFromUserId(req.userId));

  const callLog = await getOrCreateActiveCallLog({
    req,
    appointment,
    channelName,
    uid: safeUid,
  });

  const populatedCallLog = await populateCallLog(
    VideoCallLog.findById(callLog._id)
  );

  return res.status(200).json({
    success: true,
    message: "Video call join logged successfully.",
    data: populatedCallLog.toSafeObject(),
  });
});

const markVideoCallEnded = asyncHandler(async (req, res) => {
  const { channelName } = req.body;

  const result = await getAppointmentForChannel(req, channelName);

  if (result.error) {
    return res.status(result.statusCode).json(result.error);
  }

  const appointment = result.appointment;

  const callLog = await VideoCallLog.findOne({
    appointment: appointment._id,
    channelName,
    status: {
      $in: [VideoCallLog.statuses.RINGING, VideoCallLog.statuses.ACTIVE],
    },
  }).sort({
    startedAt: -1,
  });

  if (!callLog) {
    return res.status(404).json({
      success: false,
      message: "Active video call log not found.",
    });
  }

  callLog.status = VideoCallLog.statuses.ENDED;
  callLog.endedBy = req.userId;
  callLog.endedAt = new Date();
  callLog.durationSeconds = Math.max(
    0,
    Math.floor((callLog.endedAt.getTime() - callLog.startedAt.getTime()) / 1000)
  );

  await callLog.save();

  const populatedCallLog = await populateCallLog(
    VideoCallLog.findById(callLog._id)
  );

  return res.status(200).json({
    success: true,
    message: "Video call ended successfully.",
    data: populatedCallLog.toSafeObject(),
  });
});

const getAppointmentVideoCallLogs = asyncHandler(async (req, res) => {
  const appointment = await Appointment.findById(req.params.appointmentId);

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  const access = canViewAppointmentCallLogs(req, appointment);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  const logs = await populateCallLog(
    VideoCallLog.find({
      appointment: appointment._id,
    }).sort({
      startedAt: -1,
    })
  );

  return res.status(200).json({
    success: true,
    message: "Video call logs fetched successfully.",
    count: logs.length,
    data: logs.map((log) => log.toSafeObject()),
  });
});

const startVideoCall = asyncHandler(async (req, res) => {
  const { appointmentId, receiverId, channelName } = req.body;

  if (!appointmentId) {
    return res.status(400).json({
      success: false,
      message: "appointmentId is required.",
    });
  }

  const appointment = await Appointment.findById(appointmentId)
    .populate("requestedBy", "fullName email phoneNumber fcmTokens")
    .populate("rhu", "name code municipality province");

  if (!appointment) {
    return res.status(404).json({
      success: false,
      message: "Appointment not found.",
    });
  }

  if (appointment.status !== Appointment.statuses.ACCEPTED) {
    return res.status(400).json({
      success: false,
      message: "Only accepted appointments can start video calls.",
    });
  }

  if (appointment.appointmentType !== Appointment.types.ONLINE) {
    return res.status(400).json({
      success: false,
      message: "Video call is only available for online consultations.",
    });
  }

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) !== getIdString(appointment.rhu)) {
      return res.status(403).json({
        success: false,
        message: "You can only start video calls under your assigned RHU.",
      });
    }
  }

  if (
    req.user.role !== USER_ROLES.RHU_ADMIN &&
    req.user.role !== USER_ROLES.IPHO_ADMIN
  ) {
    return res.status(403).json({
      success: false,
      message: "Only RHU admins can start incoming video calls.",
    });
  }

  let receiver = null;

  if (receiverId) {
    receiver = await User.findById(receiverId);
  }

  if (!receiver) {
    receiver = appointment.requestedBy;
  }

  if (!receiver) {
    return res.status(400).json({
      success: false,
      message: "Public user receiver was not found for this appointment.",
    });
  }

  const safeChannelName =
    channelName && validateChannelName(channelName)
      ? channelName.trim()
      : `rhu_appointment_${appointment._id}`;

  const callerName = req.user.fullName || "RHU Admin";
  const rhuName =
    appointment.rhu && appointment.rhu.name
      ? appointment.rhu.name
      : "RHU Video Consultation";

  const existingCall = await VideoCallLog.findOne({
    appointment: appointment._id,
    channelName: safeChannelName,
    status: {
      $in: [VideoCallLog.statuses.RINGING, VideoCallLog.statuses.ACTIVE],
    },
  }).sort({
    startedAt: -1,
  });

  const callLog =
    existingCall ||
    (await VideoCallLog.create({
      appointment: appointment._id,
      rhu: appointment.rhu._id || appointment.rhu,
      channelName: safeChannelName,
      startedBy: req.userId,
      receiver: receiver._id || receiver.id,
      callerName,
      rhuName,
      status: VideoCallLog.statuses.RINGING,
      startedAt: new Date(),
      participants: [],
    }));

  const payload = buildCallPayload(callLog);

  const fcmResult = await sendIncomingCallFcm({
    receiver,
    payload,
  });

  callLog.fcmSent = fcmResult.sent;
  callLog.fcmError = fcmResult.error || "";
  await callLog.save();

  return res.status(201).json({
    success: true,
    message: fcmResult.sent
      ? "Incoming call started and notification sent."
      : "Incoming call started, but notification was not sent.",
    data: {
      call: callLog.toSafeObject(),
      payload,
      fcm: fcmResult,
    },
  });
});

const getIncomingCall = asyncHandler(async (req, res) => {
  const callLog = await populateCallLog(
    VideoCallLog.findOne({
      receiver: req.userId,
      status: VideoCallLog.statuses.RINGING,
    }).sort({
      createdAt: -1,
    })
  );

  if (!callLog) {
    return res.status(200).json({
      success: true,
      message: "No incoming call.",
      data: null,
    });
  }

  return res.status(200).json({
    success: true,
    message: "Incoming call fetched successfully.",
    data: {
      call: callLog.toSafeObject(),
      payload: buildCallPayload(callLog),
    },
  });
});

const acceptVideoCall = asyncHandler(async (req, res) => {
  const callLog = await VideoCallLog.findById(req.params.callId);

  if (!callLog) {
    return res.status(404).json({
      success: false,
      message: "Call not found.",
    });
  }

  if (getIdString(callLog.receiver) !== req.userId.toString()) {
    return res.status(403).json({
      success: false,
      message: "You can only accept your own incoming call.",
    });
  }

  callLog.status = VideoCallLog.statuses.ACTIVE;
  callLog.acceptedAt = callLog.acceptedAt || new Date();

  await callLog.save();

  return res.status(200).json({
    success: true,
    message: "Call accepted.",
    data: {
      call: callLog.toSafeObject(),
      payload: buildCallPayload(callLog),
    },
  });
});

const declineVideoCall = asyncHandler(async (req, res) => {
  const callLog = await VideoCallLog.findById(req.params.callId);

  if (!callLog) {
    return res.status(404).json({
      success: false,
      message: "Call not found.",
    });
  }

  if (getIdString(callLog.receiver) !== req.userId.toString()) {
    return res.status(403).json({
      success: false,
      message: "You can only decline your own incoming call.",
    });
  }

  callLog.status = VideoCallLog.statuses.DECLINED;
  callLog.declinedAt = new Date();
  callLog.endedAt = new Date();
  callLog.endedBy = req.userId;

  await callLog.save();

  return res.status(200).json({
    success: true,
    message: "Call declined.",
    data: callLog.toSafeObject(),
  });
});

const endVideoCall = asyncHandler(async (req, res) => {
  const callLog = await VideoCallLog.findById(req.params.callId);

  if (!callLog) {
    return res.status(404).json({
      success: false,
      message: "Call not found.",
    });
  }

  callLog.status = VideoCallLog.statuses.ENDED;
  callLog.endedAt = new Date();
  callLog.endedBy = req.userId;
  callLog.durationSeconds = Math.max(
    0,
    Math.floor((callLog.endedAt.getTime() - callLog.startedAt.getTime()) / 1000)
  );

  await callLog.save();

  return res.status(200).json({
    success: true,
    message: "Call ended.",
    data: callLog.toSafeObject(),
  });
});

module.exports = {
  getAgoraToken,
  markVideoCallJoined,
  markVideoCallEnded,
  getAppointmentVideoCallLogs,
  startVideoCall,
  getIncomingCall,
  acceptVideoCall,
  declineVideoCall,
  endVideoCall,
};