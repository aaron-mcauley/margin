import { Request, Response } from "express";
import { askOpenAI } from "../services/openai.service";
import { generateHandwritingStrokes } from "../services/handwriting/handwriting.service";

export async function askAI(req: Request, res: Response) {
    try {
        console.log("REQ BODY:", req.body);
        console.log("askAI start");

        const { prompt, imageBase64, underline, placement } = req.body;

        if (!prompt && !imageBase64) {
            return res.status(400).json({
                error: "Either prompt or image is required",
            });
        }

        const answer = await askOpenAI({ prompt, imageBase64 });

        // If the frontend isn't requesting handwriting,
        // just return the AI answer.
        if (!underline || !placement) {
            return res.json({ answer });
        }

        // Later this will come from the logged-in user's profile.
        const profile = undefined;

        const strokes = generateHandwritingStrokes({
            text: answer,
            placement,
        });

        return res.json({
            answer,
            strokes,
        });

    } catch (error) {
        console.error(error);

        return res.status(500).json({
            error:
                error instanceof Error
                    ? error.message
                    : "Failed to process AI request.",
        });
    }
}

export async function generateHandwriting(req: Request, res: Response): Promise<void> {
    try {
        const { text, placement } = req.body;

        const strokes = await generateHandwritingStrokes({ text, placement });

        res.status(200).json({ strokes, });

    } catch (error) {
        console.error(error);

        res.status(500).json({ error: "Failed to generate handwriting.", });
    }
};