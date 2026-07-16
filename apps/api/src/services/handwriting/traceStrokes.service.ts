import { spawn } from "node:child_process";
import path from "node:path";
import type { RenderedTextImage, SkeletonPath } from "./handwriting.types";

export const traceSkeletonToPaths = async (
    image: RenderedTextImage,
): Promise<SkeletonPath[]> => {
    const scriptPath = path.resolve(
        process.cwd(),
        "python/handwriting/trace_strokes.py",
    );

    const payload = JSON.stringify({
        width: image.width,
        height: image.height,
        pixels: Array.from(image.pixels),
    });

    return new Promise((resolve, reject) => {
        const python = spawn("python3", [scriptPath]);

        let stdout = "";
        let stderr = "";

        python.stdout.on("data", (data) => {
            stdout += data.toString();
        });

        python.stderr.on("data", (data) => {
            stderr += data.toString();
        });

        python.on("error", reject);

        python.on("close", (code) => {
            if (code !== 0) {
                reject(new Error(stderr || `Python exited with code ${code}`));
                return;
            }

            try {
                const parsed = JSON.parse(stdout);
                resolve(parsed.paths);
            } catch (error) {
                reject(error);
            }
        });

        python.stdin.write(payload);
        python.stdin.end();
    });
};