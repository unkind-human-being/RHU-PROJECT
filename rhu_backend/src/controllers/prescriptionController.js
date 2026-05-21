const Prescription = require("../models/Prescription");
const RHU = require("../models/RHU");
const Medicine = require("../models/Medicine");
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

const getPrescriptionRhuId = (prescription) => getIdString(prescription.rhu);

const getPrescriptionPatientUserId = (prescription) => {
  return getIdString(prescription.patientUser);
};

const getPrescriptionPatientName = (prescription) => {
  const firstName = prescription.patientFirstName || "";
  const middleInitial = prescription.patientMiddleInitial || "";
  const lastName = prescription.patientLastName || "";

  const name = [firstName, middleInitial, lastName]
    .filter(Boolean)
    .join(" ")
    .trim();

  if (name) {
    return name;
  }

  if (prescription.patientUser?.fullName) {
    return prescription.patientUser.fullName;
  }

  return "Patient";
};

const getPrescriptionMedicineSummary = (prescription) => {
  if (
    !Array.isArray(prescription.medicines) ||
    prescription.medicines.length === 0
  ) {
    return "prescribed medicine";
  }

  const names = prescription.medicines
    .map((item) => item.medicineName || item.medicine?.name || "")
    .filter(Boolean);

  if (names.length === 0) {
    return "prescribed medicine";
  }

  if (names.length === 1) {
    return names[0];
  }

  return `${names[0]} and ${names.length - 1} more`;
};

const safeNotifyPrescriptionCreated = async ({ req, prescription }) => {
  try {
    const patientUserId = getPrescriptionPatientUserId(prescription);

    if (!patientUserId) {
      return;
    }

    await createNotification({
      recipient: patientUserId,
      actor: req.userId,
      type: "prescription_qr_received",
      title: "Prescription QR Received",
      body: `Your prescription QR is ready. Medicine: ${getPrescriptionMedicineSummary(
        prescription
      )}.`,
      targetRoute: "/public-messages",
      rhu: getPrescriptionRhuId(prescription),
      appointment: getIdString(prescription.appointment),
      prescription: prescription._id,
      metadata: {
        prescriptionId: prescription._id.toString(),
        doctorName: prescription.doctorName || "",
        diagnosis: prescription.diagnosis || "",
        expiresAt: prescription.expiresAt || null,
      },
    });
  } catch (error) {
    console.error("Prescription created notification failed:", error.message);
  }
};

const safeNotifyPrescriptionClaimed = async ({ req, prescription }) => {
  try {
    const patientName = getPrescriptionPatientName(prescription);
    const pharmacyName =
      prescription.pharmacyName || req.user?.fullName || "Pharmacy";

    await notifyRhuAdmins({
      rhu: getPrescriptionRhuId(prescription),
      actor: req.userId,
      type: "prescription_claimed",
      title: "Prescription QR Claimed",
      body: `${patientName}'s prescription QR was claimed at ${pharmacyName}.`,
      targetRoute: "/prescription-claim-monitor",
      appointment: getIdString(prescription.appointment),
      prescription: prescription._id,
      metadata: {
        prescriptionId: prescription._id.toString(),
        patientName,
        pharmacyName,
        pharmacyLocation: prescription.pharmacyLocation || "",
        claimedAt: prescription.claimedAt || null,
      },
    });
  } catch (error) {
    console.error("Prescription claimed notification failed:", error.message);
  }
};

const canAccessPrescription = (req, prescription) => {
  if (req.user.role === USER_ROLES.IPHO_ADMIN) {
    return {
      allowed: true,
    };
  }

  const prescriptionRhuId = getIdString(prescription.rhu);

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    if (getUserRhuId(req) === prescriptionRhuId) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access prescriptions under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.PHARMACIST) {
    if (getUserRhuId(req) === prescriptionRhuId) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message:
        "You can only access prescription QR records under your assigned RHU.",
    };
  }

  if (req.user.role === USER_ROLES.PUBLIC_USER) {
    if (getPrescriptionPatientUserId(prescription) === req.userId.toString()) {
      return {
        allowed: true,
      };
    }

    return {
      allowed: false,
      message: "You can only access your own prescription QR records.",
    };
  }

  return {
    allowed: false,
    message: "You do not have permission to access prescription records.",
  };
};

const buildPrescriptionFilter = (req) => {
  const filter = {};

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    filter.rhu = getUserRhuId(req);
  }

  if (req.user.role === USER_ROLES.PHARMACIST) {
    filter.rhu = getUserRhuId(req);
  }

  if (req.user.role === USER_ROLES.IPHO_ADMIN && req.query.rhu) {
    filter.rhu = req.query.rhu;
  }

  if (req.query.status) {
    filter.status = req.query.status;
  }

  if (req.query.patientUser) {
    filter.patientUser = req.query.patientUser;
  }

  if (req.user.role === USER_ROLES.PUBLIC_USER) {
    filter.patientUser = req.userId;
  }

  if (req.query.search) {
    const searchRegex = new RegExp(req.query.search.trim(), "i");

    filter.$or = [
      { patientLastName: searchRegex },
      { patientFirstName: searchRegex },
      { contactNumber: searchRegex },
      { doctorName: searchRegex },
      { pharmacyName: searchRegex },
    ];
  }

  return filter;
};

const buildPrescriptionQrPayload = (prescription) => {
  return {
    type: "rhu_prescription_qr",
    version: 1,
    token: prescription.qrToken,
    prescriptionId: prescription._id.toString(),
    rhu: getIdString(prescription.rhu),
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

const populatePrescription = (query) => {
  return query
    .populate("rhu", "name code municipality province")
    .populate("patientUser", "fullName email phoneNumber")
    .populate("prescribedBy", "fullName email role")
    .populate("claimedBy", "fullName email role")
    .populate("medicines.medicine", "name genericName strength unit category");
};

const getPrescriptions = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  const skip = (page - 1) * limit;

  const filter = buildPrescriptionFilter(req);

  const [prescriptions, total] = await Promise.all([
    populatePrescription(
      Prescription.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
    ),
    Prescription.countDocuments(filter),
  ]);

  return res.status(200).json({
    success: true,
    message: "Prescription records fetched successfully.",
    count: prescriptions.length,
    total,
    page,
    pages: Math.ceil(total / limit),
    data: prescriptions.map((item) => item.toSafeObject()),
  });
});

const getMyPrescriptions = asyncHandler(async (req, res) => {
  req.query.patientUser = req.userId;

  return getPrescriptions(req, res);
});

const getPrescriptionById = asyncHandler(async (req, res) => {
  const prescription = await populatePrescription(
    Prescription.findById(req.params.id)
  );

  if (!prescription) {
    return res.status(404).json({
      success: false,
      message: "Prescription not found.",
    });
  }

  const access = canAccessPrescription(req, prescription);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  return res.status(200).json({
    success: true,
    message: "Prescription fetched successfully.",
    data: prescription.toSafeObject(),
  });
});

const getPrescriptionByQrToken = asyncHandler(async (req, res) => {
  const prescription = await populatePrescription(
    Prescription.findOne({
      qrToken: req.params.token,
    })
  );

  if (!prescription) {
    return res.status(404).json({
      success: false,
      message: "Prescription QR was not found.",
    });
  }

  const access = canAccessPrescription(req, prescription);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (prescription.status === Prescription.statuses.ISSUED) {
    if (prescription.isExpiredNow()) {
      prescription.status = Prescription.statuses.EXPIRED;
      await prescription.save();
    }
  }

  return res.status(200).json({
    success: true,
    message: "Prescription QR fetched successfully.",
    data: prescription.toSafeObject(),
  });
});

const createPrescription = asyncHandler(async (req, res) => {
  const {
    rhu,
    appointment,
    patientUser,
    patientLastName,
    patientFirstName,
    patientMiddleInitial,
    patientAge,
    patientSex,
    contactNumber,
    diagnosis,
    doctorName,
    medicines,
    expiresAt,
  } = req.body;

  if (!patientLastName || !patientFirstName) {
    return res.status(400).json({
      success: false,
      message: "Patient first name and last name are required.",
    });
  }

  if (!Array.isArray(medicines) || medicines.length === 0) {
    return res.status(400).json({
      success: false,
      message: "At least one prescribed medicine is required.",
    });
  }

  let assignedRhu = rhu;

  if (req.user.role === USER_ROLES.RHU_ADMIN) {
    assignedRhu = getUserRhuId(req);
  }

  if (!assignedRhu) {
    return res.status(400).json({
      success: false,
      message: "RHU is required.",
    });
  }

  const existingRhu = await RHU.findById(assignedRhu);

  if (!existingRhu || !existingRhu.isActive) {
    return res.status(400).json({
      success: false,
      message: "Selected RHU does not exist or is inactive.",
    });
  }

  if (
    req.user.role === USER_ROLES.RHU_ADMIN &&
    getUserRhuId(req) !== assignedRhu.toString()
  ) {
    return res.status(403).json({
      success: false,
      message: "RHU admins can only create prescriptions under their own RHU.",
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
      message: "Invalid QR expiration date.",
    });
  }

  const prescription = await Prescription.create({
    rhu: assignedRhu,
    appointment: appointment || null,
    patientUser: patientUser || null,
    patientLastName,
    patientFirstName,
    patientMiddleInitial,
    patientAge,
    patientSex,
    contactNumber,
    diagnosis,
    doctorName: doctorName || "DR. Alnidzfar-nadz D. Jericho",
    prescribedBy: req.userId,
    medicines: normalizedMedicines,
    expiresAt: expirationDate,
  });

  prescription.qrPayload = JSON.stringify(
    buildPrescriptionQrPayload(prescription)
  );

  await prescription.save();

  const populatedPrescription = await populatePrescription(
    Prescription.findById(prescription._id)
  );

  await safeNotifyPrescriptionCreated({
    req,
    prescription: populatedPrescription,
  });

  return res.status(201).json({
    success: true,
    message: "Prescription QR created successfully.",
    data: populatedPrescription.toSafeObject(),
  });
});

const cancelPrescription = asyncHandler(async (req, res) => {
  const prescription = await Prescription.findById(req.params.id);

  if (!prescription) {
    return res.status(404).json({
      success: false,
      message: "Prescription not found.",
    });
  }

  const access = canAccessPrescription(req, prescription);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (prescription.status === Prescription.statuses.CLAIMED) {
    return res.status(400).json({
      success: false,
      message: "Claimed prescriptions cannot be cancelled.",
    });
  }

  prescription.status = Prescription.statuses.CANCELLED;
  await prescription.save();

  return res.status(200).json({
    success: true,
    message: "Prescription cancelled successfully.",
    data: prescription.toSafeObject(),
  });
});

const claimPrescription = asyncHandler(async (req, res) => {
  const { pharmacyName, pharmacyLocation, claimRemarks } = req.body;

  const prescription = await Prescription.findById(req.params.id);

  if (!prescription) {
    return res.status(404).json({
      success: false,
      message: "Prescription not found.",
    });
  }

  const access = canAccessPrescription(req, prescription);

  if (!access.allowed) {
    return res.status(403).json({
      success: false,
      message: access.message,
    });
  }

  if (req.user.role !== USER_ROLES.PHARMACIST) {
    return res.status(403).json({
      success: false,
      message: "Only pharmacist accounts can claim prescription QR records.",
    });
  }

  if (prescription.status === Prescription.statuses.CLAIMED) {
    return res.status(400).json({
      success: false,
      message: "This prescription QR was already claimed.",
    });
  }

  if (prescription.status === Prescription.statuses.CANCELLED) {
    return res.status(400).json({
      success: false,
      message: "This prescription QR was cancelled.",
    });
  }

  if (prescription.isExpiredNow()) {
    prescription.status = Prescription.statuses.EXPIRED;
    await prescription.save();

    return res.status(400).json({
      success: false,
      message: "This prescription QR is already expired.",
    });
  }

  prescription.status = Prescription.statuses.CLAIMED;
  prescription.claimedAt = new Date();
  prescription.claimedBy = req.userId;
  prescription.pharmacyName = pharmacyName || req.user.fullName || "Pharmacy";
  prescription.pharmacyLocation = pharmacyLocation || "";
  prescription.claimRemarks = claimRemarks || "";

  await prescription.save();

  const populatedPrescription = await populatePrescription(
    Prescription.findById(prescription._id)
  );

  await safeNotifyPrescriptionClaimed({
    req,
    prescription: populatedPrescription,
  });

  return res.status(200).json({
    success: true,
    message: "Prescription QR claimed successfully.",
    data: populatedPrescription.toSafeObject(),
  });
});

module.exports = {
  getPrescriptions,
  getMyPrescriptions,
  getPrescriptionById,
  getPrescriptionByQrToken,
  createPrescription,
  cancelPrescription,
  claimPrescription,
};