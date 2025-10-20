import mongoose from 'mongoose';
const userSchema = new mongoose.Schema({
    username: { type: String, required: true, unique: true, trim: true, lowercase: true },
    password: { type: String, required: true, select: false },
    role: { type: String, required: true, enum: ['driver', 'police'] }
}, { timestamps: true });
const UserModel = mongoose.model('User', userSchema);
export default UserModel;
//# sourceMappingURL=userModel.js.map