import { Router } from "express";
import { signup, login } from "../controller/authController.js";
const userRouter = Router();
userRouter.post('/signup', signup);
userRouter.post('/login', login);
export default userRouter;
//# sourceMappingURL=routes.js.map