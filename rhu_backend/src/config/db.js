const mongoose = require("mongoose");

const connectDatabase = async () => {
  const mongoUri = process.env.MONGO_URI;

  if (!mongoUri) {
    console.error("MONGO_URI is missing in your .env file.");
    process.exit(1);
  }

  try {
    const connection = await mongoose.connect(mongoUri, {
      autoIndex: process.env.NODE_ENV !== "production",
    });

    console.log(`MongoDB Atlas connected: ${connection.connection.host}`);

    return connection;
  } catch (error) {
    console.error("MongoDB Atlas connection failed.");
    console.error(error.message);
    process.exit(1);
  }
};

const closeDatabase = async () => {
  try {
    await mongoose.connection.close();
    console.log("MongoDB connection closed.");
  } catch (error) {
    console.error("Error closing MongoDB connection.");
    console.error(error.message);
  }
};

mongoose.connection.on("connected", () => {
  console.log("Mongoose connected to MongoDB Atlas.");
});

mongoose.connection.on("error", (error) => {
  console.error("Mongoose connection error:", error.message);
});

mongoose.connection.on("disconnected", () => {
  console.warn("Mongoose disconnected from MongoDB Atlas.");
});

process.on("SIGINT", async () => {
  await closeDatabase();
  process.exit(0);
});

process.on("SIGTERM", async () => {
  await closeDatabase();
  process.exit(0);
});

module.exports = {
  connectDatabase,
  closeDatabase,
};