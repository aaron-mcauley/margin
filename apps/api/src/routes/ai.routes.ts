import { Router } from "express";
import { askAI, generateHandwriting } from "../controllers/ai.controller";

const router = Router();

router.post("/ask", askAI);
router.post("/handwriting", generateHandwriting)

export default router;