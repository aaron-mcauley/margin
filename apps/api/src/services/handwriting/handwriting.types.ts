// src/services/handwriting/handwriting.types.ts

export type Stroke = {
    id: string;
    points: number[];
    type: "ink" | "underline";
    width: number;
    color: string;
    characterIndex?: number;
    character?: string;
};

export type HandwritingPlacement = {
    x: number;
    y: number;
    averageLineHeight: number;
    width: number;
    color: string;
    maxWidth?: number;
};

export type GenerateHandwritingInput = {
    text: string;
    placement: HandwritingPlacement;
};

export type RenderedTextImage = {
    width: number;
    height: number;
    pixels: Uint8ClampedArray;
};

export type SkeletonPoint = {
    x: number;
    y: number;
};

export type SkeletonPath = SkeletonPoint[];
