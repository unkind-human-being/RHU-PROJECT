const { cloudinary, configureCloudinary } = require("../config/cloudinary");
const { asyncHandler } = require("../middleware/errorMiddleware");

const uploadBufferToCloudinary = ({
  buffer,
  folder,
  publicIdPrefix,
}) => {
  return new Promise((resolve, reject) => {
    const uploadStream = cloudinary.uploader.upload_stream(
      {
        folder,
        public_id: `${publicIdPrefix}_${Date.now()}`,
        resource_type: "image",
        transformation: [
          {
            width: 900,
            height: 900,
            crop: "limit",
            quality: "auto",
            fetch_format: "auto",
          },
        ],
      },
      (error, result) => {
        if (error) {
          return reject(error);
        }

        return resolve(result);
      }
    );

    uploadStream.end(buffer);
  });
};

const uploadAppointmentPhoto = asyncHandler(async (req, res) => {
  const configured = configureCloudinary();

  if (!configured) {
    return res.status(500).json({
      success: false,
      message:
        "Cloudinary configuration is missing. Please set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET in .env.",
    });
  }

  if (!req.file) {
    return res.status(400).json({
      success: false,
      message: "Please upload an appointment image.",
    });
  }

  const folder =
    process.env.CLOUDINARY_APPOINTMENT_FOLDER || "rhu/appointment-photos";

  const userId = req.userId ? req.userId.toString() : "unknown_user";

  const result = await uploadBufferToCloudinary({
    buffer: req.file.buffer,
    folder,
    publicIdPrefix: `appointment_${userId}`,
  });

  return res.status(201).json({
    success: true,
    message: "Appointment photo uploaded successfully.",
    data: {
      url: result.secure_url,
      publicId: result.public_id,
      width: result.width,
      height: result.height,
      format: result.format,
      bytes: result.bytes,
    },
  });
});

module.exports = {
  uploadAppointmentPhoto,
};