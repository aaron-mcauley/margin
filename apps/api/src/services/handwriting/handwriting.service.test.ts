import { describe, expect, it } from "vitest";
import { generateHandwritingStrokes } from "./handwriting.service";

describe("generateHandwritingStrokes", () => {
    it("runs the full Python handwriting pipeline and returns valid strokes", async () => {
        const strokes = await generateHandwritingStrokes({
            text: "Hello world",
            placement: {
                x: 100,
                y: 200,
                averageLineHeight: 24,
                width: 1.3,
                color: "#111111",
                maxWidth: 520,
            },
        });

        expect(Array.isArray(strokes)).toBe(true);
        expect(strokes.length).toBeGreaterThan(0);

        for (const stroke of strokes) {
            expect(typeof stroke.id).toBe("string");
            expect(stroke.type).toBe("ink");
            expect(stroke.width).toBe(1.3);
            expect(stroke.color).toBe("#111111");

            expect(Array.isArray(stroke.points)).toBe(true);
            expect(stroke.points.length).toBeGreaterThanOrEqual(4);
            expect(stroke.points.length % 2).toBe(0);

            for (const coordinate of stroke.points) {
                expect(typeof coordinate).toBe("number");
                expect(Number.isFinite(coordinate)).toBe(true);
            }
        }
    }, 20_000);
});