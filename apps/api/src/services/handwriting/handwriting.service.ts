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

    console.log("RENDERED IMAGE:", {
        width: renderedImage.width,
        height: renderedImage.height,
        pixelCount: renderedImage.pixels.length,
    });

    const skeletonImage = await skeletonizeImage(renderedImage);

    console.log("SKELETON IMAGE:", {
        width: skeletonImage.width,
        height: skeletonImage.height,
        pixelCount: skeletonImage.pixels.length,
    });

    const paths = await traceSkeletonToPaths(skeletonImage);

    console.log("TRACE RESULTS:", {
        pathCount: paths.length,
        firstPathLength: paths[0]?.length,
        firstPath: paths[0]?.slice(0, 5),
        placement,
    });

    const strokes: Stroke[] = paths.map((path) => ({
        id: makeId(),
        type: "ink",
        //width: placement.width,
        width: placement.width,
        color: placement.color,
        points: path.flatMap((point) => [
            placement.x + point.x,
            placement.y + point.y,
        ]),
    }));

    console.log("GENERATED STROKES:", {
        strokeCount: strokes.length,
        firstStroke: strokes[0],
    });

    return strokes;
};