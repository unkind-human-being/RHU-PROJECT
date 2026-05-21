const express = require("express");

const { uploadAppointmentPhoto } = require("../controllers/uploadController");
const { appointmentPhotoUpload } = require("../middleware/uploadMiddleware");
const { protect } = require("../middleware/authMiddleware");
const { allowRoles } = require("../middleware/roleMiddleware");
const { USER_ROLES } = require("../utils/constants");

const router = express.Router();

const canUploadAppointmentPhoto = allowRoles(
  USER_ROLES.PUBLIC_USER,
  USER_ROLES.RHU_ADMIN,
  USER_ROLES.IPHO_ADMIN
);

router.post(
  "/appointment-photo",
  protect,
  canUploadAppointmentPhoto,
  appointmentPhotoUpload.single("image"),
  uploadAppointmentPhoto
);

module.exports = router;