import bcrypt from 'bcrypt'
import z, { success } from 'zod';
import jwt from 'jsonwebtoken'
import UserModel from '../model/userModel.js';
import type{ Request , Response} from 'express';
const JWT_SECRET = process.env.JWT_SECRET || "secret";



export const signup = async(req : Request , res : Response) =>{
    try {
    const {username , password , role} = req.body ;
    // Normalize role coming from frontend which uses 'driver'|'police'
    const normalizedRole = role === 'driver' ? 'driver' : 'police';
        const existingUser = await UserModel.findOne({username});

        if(existingUser){
            return res.status(400).json({
                success : false,
                message : "User already exists"
            })
        }

        const hashedPassword = await bcrypt.hash(password , 10);

        const user = await UserModel.create({
            username,
            password : hashedPassword,
            role: normalizedRole
        })
        
        const token = jwt.sign({
            id : user._id,
            role: user.role
        } , JWT_SECRET)

        return res.status(201).json({
            success : true,
            message : "User created successfully",
            token,
            role: user.role,
            id: user._id
        })
    } catch (error : any) {
        console.log(error);
        return res.status(500).json({
            success : false,
            message : error.message
        })
    }
}

export const login = async(req : Request , res : Response)=>{
    try {
    const {username , password} = req.body;
    // Explicitly select the password field for comparison.
    const user = await UserModel.findOne({username}).select('+password');

        if(!user){
            return res.status(404).json({
                success : false,
                message : "User not found"
            })
        }

        const isMatch = await bcrypt.compare(password , user.password);

        if(!isMatch){
            return res.status(401).json({
                success : false,
                message : "Invalid credentials"
            })
        }
        
        const token = jwt.sign({
            id : user._id,
            role: user.role
        } , JWT_SECRET)

        return res.status(200).json({
            success : true,
            message : "User logged in successfully",
            token,
            role: user.role,
            id: user._id
        })
    } catch (error : any) {
        console.log(error);
        return res.status(500).json({
            success : false,
            message : error.message
        })
    }
}