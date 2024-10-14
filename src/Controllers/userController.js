// Import the necessary modules and services
import { createUser as createUserService, getUserByEmail, updateUser as updateUserService } from '../services/userService.js';


// Allowed headers list
const allowedHeaders = [
  'content-type',
  'accept',
  'user-agent',
  'host',
  'content-length',
  'accept-encoding',
  'connection',
  'authorization',
  'content-type',
  'content-length',
  'postman-token'  // Include authorization header for basic auth
];

// Create a new user
// export const createUser = async (req, res) => {
//   try {
//     // Check for unexpected headers
//     const hasUnexpectedHeaders = Object.keys(req.headers).some(
//       (header) => !allowedHeaders.includes(header.toLowerCase())
//     );

//     if (hasUnexpectedHeaders) {
//       return res.status(400).json({ message: `Unexpected headers in the request.` });
//     }

//     const { first_name, last_name, email, password } = req.body;

//     // Check for missing fields
//     if (!first_name || !last_name || !email || !password) {
//       return res.status(400).json({ error: 'All fields are required.' });
//     }

//     // Check if the email already exists
//     const existingUser = await getUserByEmail(email);
//     if (existingUser) {
//       return res.status(400).json({ error: 'Email already in use.' });
//     }

//     // Create the user using the service
//     const newUser = await createUserService(req.body);

//     // Construct the response
//     const response = {
//       id: newUser.id,
//       first_name: newUser.first_name,
//       last_name: newUser.last_name,
//       email: newUser.email,
//       account_created: newUser.account_created,
//       account_updated: newUser.account_updated,
//     };

//     res.status(201).json(response);
//   } catch (error) {
//     console.error('Error creating user:', error);
//     res.status(500).json({ error: 'An error occurred while creating the user.' });
//   }
// };

// Get user information
// export const getUserInfo = async (req, res) => {
//   try {
//     // Assuming `req.user` contains the authenticated user's information, such as their email
//     const userEmail = req.user ? req.user.email : null;

//     // If the email is not present, return a 404
//     if (!userEmail) {
//       return res.status(404).json({ error: 'User not found.' });
//     }

//     // Fetch the user from the database
//     const user = await getUserByEmail(userEmail);

//     if (!user) {
//       return res.status(404).json({ error: 'User not found.' });
//     }

//     // Construct the response, excluding the password
//     const response = {
//       id: user.id,
//       first_name: user.first_name,
//       last_name: user.last_name,
//       email: user.email,
//       account_created: user.account_created,
//       account_updated: user.account_updated,
//     };

//     res.status(200).json(response);
//   } catch (error) {
//     console.error('Error fetching user information:', error);
//     res.status(500).json({ error: 'An error occurred while fetching user information.' });
//   }
// };


// Get user information
export const getUserInfo = async (req, res) => {
  try {
    // Assuming `req.user` contains the authenticated user's information, set by the authenticateUser middleware
    const user = req.user;

    if (!getUserByEmail) {
      // This case should not normally happen because the authentication middleware should already handle invalid users
      return res.status(400).json({ error: 'User not found.' });
    }

    // Construct the response, excluding the password
    const response = {
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      account_created: user.account_created,
      account_updated: user.account_updated,
    };

    res.status(200).json(response);
  } catch (error) {
    console.error('Error fetching user information:', error);
    res.status(500).json({ error: 'An error occurred while fetching user information.' });
  }
};


// Update user information
export const updateUser = async (req, res) => {
  try {
    const { first_name, last_name, password } = req.body; // Only capture fields that can be updated
    const allowedFields = ['first_name', 'last_name', 'password'];

    // Check if any unsupported fields are provided in the request
    const fieldsToUpdate = Object.keys(req.body);
    const invalidFields = fieldsToUpdate.filter(field => !allowedFields.includes(field));

    if (invalidFields.length > 0) {
      return res.status(400).json({ error: `Cannot update fields: ${invalidFields.join(', ')}` });
    }

    // Get the authenticated user's email from the request (set by `authenticateUser` middleware)
    const userEmail = req.user.email;

    // Update user information in the service layer
    const updatedUser = await updateUserService(userEmail, { first_name, last_name, password });

    if (!updatedUser) {
      return res.status(404).json({ error: 'User not found.' });
    }

    // Return 204 No Content for successful update
    res.status(204).end();
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ error: 'An error occurred while updating the user.' });
  }
};
