
import { spawn } from "node:child_process";
import path from "node:path";
import { randomUUID } from "node:crypto";
import type {
    GenerateHandwritingInput,
    Stroke,
} from "./handwriting.types";

type GeneratedPath = {
    characterIndex: number;
    character: string;
    points: { x: number; y: number }[];
};

export const generateHandwritingStrokes = async ({
    text,
    placement,
}: GenerateHandwritingInput): Promise<Stroke[]> => {
    const scriptPath = path.resolve(
        process.cwd(),
        "python/handwriting/ordered_strokes.py"
    );

    const paths = await new Promise<GeneratedPath[]>((resolve, reject) => {
        const python = spawn("python3", [scriptPath]);

        let stdout = "";
        let stderr = "";

        python.stdout.on("data", (data: Buffer) => {
            stdout += data.toString();
        });

        python.stderr.on("data", (data: Buffer) => {
            stderr += data.toString();
        });

        python.on("error", reject);

        python.on("close", (code) => {
            if (code !== 0) {
                reject(
                    new Error(stderr || `Python exited with code ${code}`)
                );
                return;
            }

            try {
                const result = JSON.parse(stdout) as {
                    strokes: GeneratedPath[];
                };

                resolve(result.strokes);
            } catch (error) {
                reject(error);
            }
        });

        python.stdin.end(JSON.stringify({ text, placement }));
    });

    const strokes: Stroke[] = paths.map((generatedPath) => ({
        id: randomUUID(),
        type: "ink",
        width: placement.width,
        color: placement.color,
        characterIndex: generatedPath.characterIndex,
        character: generatedPath.character,
        points: generatedPath.points.flatMap((point) => [
            placement.x + point.x,
            placement.y + point.y,
        ]),
    }));

    console.log("ORDERED HANDWRITING:", {
        strokeCount: strokes.length,
        characters: [...new Set(strokes.map((s) => s.characterIndex))].length,
        firstCharacter: strokes[0]?.character,
        lastCharacter: strokes.at(-1)?.character,
    });

    return strokes;
};
