import { renderTextToImage } from "./fontRenderer.service";
import { skeletonizeImage } from "./skeletonize.service";
import { traceSkeletonToPaths } from "./traceStrokes.service";
import type { GenerateHandwritingInput, Stroke } from "./handwriting.types";

const makeId = () => `${Date.now()}-${Math.random()}`;

export const generateHandwritingStrokes = async ({
    text,
    placement,
}: GenerateHandwritingInput): Promise<Stroke[]> => {
    const renderedImage = await renderTextToImage({
        text,
        placement,
    });

    const skeletonImage = await skeletonizeImage(renderedImage);

    const paths = await traceSkeletonToPaths(skeletonImage);

    const strokes: Stroke[] = paths.map((path) => ({
        id: makeId(),
        type: "ink",
        width: placement.width,
        color: placement.color,
        points: path.flatMap((point) => [
            placement.x + point.x,
            placement.y + point.y,
        ]),
    }));

    return strokes;
};