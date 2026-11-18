import { spawn } from "node:child_process";
import path from "node:path";
import {randomUUID } from "node:crypto";
import type { GenerateHandwritingInput, Stroke } from "./handwriting.types";

type GeneratedPath = {
    characterIndex: number;
    character: string;
    points: { x: number; y: number }[];
}

export const generateHandwritingStrokes = async ({
    text, 
    placement,
}: GenerateHandwritingInput): Promise<Stroke[]> => {
    const scriptPath = path.resolve(process.cwd(), "python/handwriting/ordered_strokes.py");
    const paths = await new Promise<GeneratedPath[]>((resolve, reject) => {
        const python = spawn("python3", [scriptPath]);
        let stdout ="";
        let stderr = "";
        python.stdout.on("data", (data: Buffer) => { stdout += data.toString(); });
        python.stderr.on("data", (data: Buffer) => { stderr += data.toString(); });
        python.on("error", reject);
        python.on("close", (code) => {
            if (code !== 0) {
                reject(new Error(stderr || `Python exited with code ${code}`));
                return;
            }
            try {
                resolve((JSON.parse(stdout) as { strokes: GeneratedPath[] }).strokes);
            } catch (error) {
                reject(error);
            }
        });
        python.stdin.end(JSON.stringify({ text, placement }));
    });

    return paths.map((path) => ({
        id: randomUUID(),
        type: "ink" as const,
        width: placement.width,
        color: placement.color,
        characterIndex: path.characterIndex,
        character: path.character,
        points: path.points.flatMap((point) => [placement.x + point.x, placement.y + point.y]),
    }));
};
