const express = require("express");
const dotenv = require("dotenv");
const cors = require("cors");
const morgan = require("morgan");
const swaggerUi = require("swagger-ui-express");
const swaggerDocument = require("./config/swagger");
const internalRoutes = require("./routes/internal.routes");

dotenv.config();

const { connectDatabase } = require("./config/db");
const { notFound, errorHandler } = require("./middleware/errorMiddleware");

const authRoutes = require("./routes/authRoutes");
const rhuRoutes = require("./routes/rhuRoutes");
const barangayRoutes = require("./routes/barangayRoutes");
const userRoutes = require("./routes/userRoutes");
const postRoutes = require("./routes/postRoutes");
const eventRoutes = require("./routes/eventRoutes");
const surveyRoutes = require("./routes/surveyRoutes");
const eventRegistrationRoutes = require("./routes/eventRegistrationRoutes");
const surveyResponseRoutes = require("./routes/surveyResponseRoutes");
const medicineRoutes = require("./routes/medicineRoutes");
const syncRoutes = require("./routes/syncRoutes");
const prescriptionRoutes = require("./routes/prescriptionRoutes");
const appointmentRoutes = require("./routes/appointmentRoutes");
const consultationMessageRoutes = require("./routes/consultationMessageRoutes");
const appointmentSettingRoutes = require("./routes/appointmentSettingRoutes");
const notificationRoutes = require("./routes/notificationRoutes");
const videoRoutes = require("./routes/videoRoutes");
const uploadRoutes = require("./routes/uploadRoutes");

const app = express();

const PORT = process.env.PORT || 5000;

app.set("trust proxy", 1);

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",").map((origin) => origin.trim())
  : ["*"];

app.use(
  cors({
    origin: allowedOrigins.includes("*")
      ? "*"
      : function (origin, callback) {
          if (!origin || allowedOrigins.includes(origin)) {
            return callback(null, true);
          }

          return callback(new Error("Not allowed by CORS."));
        },
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "X-Internal-Gateway-Secret",
      "x-internal-gateway-secret",
      "x-gateway-secret",
    ],
    credentials: allowedOrigins.includes("*") ? false : true,
  })
);

app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

if (process.env.NODE_ENV !== "production") {
  app.use(morgan("dev"));
}

app.get("/", (req, res) => {
  return res.status(200).json({
    success: true,
    message: "Tawi-Tawi RHU Mobile Portal API is running.",
    project:
      "Tawi-Tawi RHU Mobile Portal: A Health Updates and Medicine Supply Monitoring Application",
    database: "MongoDB Atlas",
    status: "online",
  });
});

app.get("/api/health", (req, res) => {
  return res.status(200).json({
    success: true,
    message: "Backend server is healthy.",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || "development",
  });
});

app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// Direct internal gateway endpoints:
// /handshake
// /verify-user
// /register-user
app.use("/", internalRoutes);

function mountApiRoutes(prefix) {
  app.use(`${prefix}/auth`, authRoutes);
  app.use(`${prefix}/rhus`, rhuRoutes);
  app.use(`${prefix}/barangays`, barangayRoutes);
  app.use(`${prefix}/users`, userRoutes);
  app.use(`${prefix}/posts`, postRoutes);
  app.use(`${prefix}/events`, eventRoutes);
  app.use(`${prefix}/surveys`, surveyRoutes);
  app.use(`${prefix}/event-registrations`, eventRegistrationRoutes);
  app.use(`${prefix}/survey-responses`, surveyResponseRoutes);
  app.use(`${prefix}/medicines`, medicineRoutes);
  app.use(`${prefix}/sync`, syncRoutes);
  app.use(`${prefix}/prescriptions`, prescriptionRoutes);
  app.use(`${prefix}/appointments`, appointmentRoutes);
  app.use(`${prefix}/consultation-messages`, consultationMessageRoutes);
  app.use(`${prefix}/appointment-settings`, appointmentSettingRoutes);
  app.use(`${prefix}/notifications`, notificationRoutes);
  app.use(`${prefix}/video`, videoRoutes);
  app.use(`${prefix}/uploads`, uploadRoutes);
  app.use(`${prefix}/internal`, internalRoutes);
}

// Original RHU app routes.
// Example: /api/rhus
mountApiRoutes("/api");

// Tawi-Tawi gateway proxy routes.
// Tawi-Tawi backend currently rewrites:
// /api/shu/rhus -> /api/v1/rhus
// /api/shu/posts/public -> /api/v1/posts/public
// /api/shu/appointments -> /api/v1/appointments
mountApiRoutes("/api/v1");

app.use(notFound);
app.use(errorHandler);

const startServer = async () => {
  await connectDatabase();

  app.listen(PORT, () => {
    console.log(`RHU backend server running on port ${PORT}`);
  });
};

startServer();

process.on("unhandledRejection", (error) => {
  console.error("Unhandled Promise Rejection:", error.message);
  process.exit(1);
});

process.on("uncaughtException", (error) => {
  console.error("Uncaught Exception:", error.message);
  process.exit(1);
});