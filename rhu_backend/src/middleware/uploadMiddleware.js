const path = require("path");
const multer = require("multer");

const storage = multer.memoryStorage();

const allowedMimeTypes = [
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
  "application/octet-stream",
];

const allowedExtensions = [
  ".jpg",
  ".jpeg",
  ".png",
  ".webp",
  ".heic",
  ".heif",
];

const imageFileFilter = (req, file, callback) => {
  const fileExtension = path
    .extname(file.originalname || "")
    .toLowerCase()
    .trim();

  const mimeType = (file.mimetype || "").toLowerCase().trim();

  const isAllowedMime = allowedMimeTypes.includes(mimeType);
  const isAllowedExtension = allowedExtensions.includes(fileExtension);

  if (!isAllowedMime && !isAllowedExtension) {
    return callback(
      new Error(
        "Only JPG, PNG, WEBP, HEIC, and HEIF image files are allowed."
      ),
      false
    );
  }

  return callback(null, true);
};

const appointmentPhotoUpload = multer({
  storage,
  fileFilter: imageFileFilter,
  limits: {
    fileSize: 8 * 1024 * 1024,
  },
});

module.exports = {
  appointmentPhotoUpload,
};