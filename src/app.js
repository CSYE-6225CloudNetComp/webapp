// app.js
import express from 'express';
import { healthCheck, methodNotAllowed } from './Controllers/healthController.js';
import { createUser, getUserInfo, updateUser } from './Controllers/userController.js'; // Import user-related controllers
import { uploadProfilePic, getProfilePic, deleteProfilePic } from './Controllers/profilePicController.js'; // Import profile picture-related controllers
import {authenticateUser, blockUnverifiedUsers} from './middleware/basicAuth.js';
import { verifyUser } from './Controllers/verificationController.js';
const app = express();
app.use(express.json());

// Define user-related routes
app.use('/v1/user/self', authenticateUser, (req, res, next) => {
  if (["HEAD", "OPTIONS", "PATCH"].includes(req.method)) {
    return res.status(405).end();
  } 
  next();
});

app.post('/v1/user', createUser);
app.get('/v1/user/self', authenticateUser, blockUnverifiedUsers, getUserInfo);
app.put('/v1/user/self', authenticateUser, blockUnverifiedUsers, updateUser);
//Define profile picture-related routes
app.post('/v1/user/self/pic', authenticateUser, blockUnverifiedUsers, async (req, res, next) => {
  try {
    await uploadProfilePic(req, res);
  } catch (error) {
    console.error("Error uploading profile picture:", error);
    next(error); // Pass error to error-handling middleware
  }
});

app.get('/v1/user/self/pic', authenticateUser, blockUnverifiedUsers, async (req, res, next) => {
  try {
    await getProfilePic(req, res);
  } catch (error) {
    console.error("Error retrieving profile picture:", error);
    next(error); // Pass error to error-handling middleware
  }
});

app.delete('/v1/user/self/pic', authenticateUser, blockUnverifiedUsers, async (req, res, next) => {
  try {
    await deleteProfilePic(req, res);
  } catch (error) {
    console.error("Error deleting profile picture:", error);
    next(error); // Pass error to error-handling middleware
  }
});

app.all('/verify', verifyUser);


// Health check routes
app.get('/cicd', healthCheck);
app.get('/healthz', healthCheck);
app.head('/healthz', methodNotAllowed);
app.all('/healthz', methodNotAllowed);

// Export the app instance for testing
export default app;