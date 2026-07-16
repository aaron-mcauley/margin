import { spawn } from "node:child_process";
import path from "node:path";
import type {
    GenerateHandwritingInput,
    RenderedTextImage,
} from "./handwriting.types";

type PythonRenderedTextImage = {
    width: number;
    height: number;
    pixels: number[];
};

export const renderTextToImage = async ({
    text,
    placement,
}: GenerateHandwritingInput): Promise<RenderedTextImage> => {
    const scriptPath = path.resolve(
        process.cwd(),
        "python/handwriting/font_renderer.py",
    );

    const payload = JSON.stringify({
        text,
        placement,
    });

    return new Promise((resolve, reject) => {
        const python = spawn("python3", [scriptPath]);

        let stdout = "";
        let stderr = "";

        python.stdout.on("data", (data: Buffer) => {
            stdout += data.toString();
        });

        python.stderr.on("data", (data: Buffer) => {
            stderr += data.toString();
        });

        python.on("error", (error) => {
            reject(error);
        });

        python.on("close", (code) => {
            if (code !== 0) {
                reject(
                    new Error(
                        stderr || `Python exited with code ${code}`,
                    ),
                );
                return;
            }

            try {

                const parsed = JSON.parse(
                    stdout,
                ) as PythonRenderedTextImage;
                const hasInk = parsed.pixels.some((pixel) => pixel < 255);

                resolve({
                    width: parsed.width,
                    height: parsed.height,
                    pixels: new Uint8ClampedArray(parsed.pixels),
                });
            } catch (error) {
                reject(
                    new Error(
                        `Failed to parse Python output as JSON.\n\nSTDOUT:\n${stdout}\n\nSTDERR:\n${stderr}\n\nOriginal error: ${error instanceof Error
                            ? error.message
                            : String(error)
                        }`,
                    ),
                );
            }
        });

        python.stdin.write(payload);
        python.stdin.end();
    });
};