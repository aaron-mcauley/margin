import { Router } from "express";
import { askAI } from "../controllers/ai.controller";

const router = Router();

router.post("/ask", askAI);
router.post("handwriting")

export default router;