import { useRef, useState } from "react";
import { Stage, Layer, Shape } from "react-konva";
import type Konva from "konva";
import "./App.scss";

type Tool = "pen" | "eraser";

type Stroke = {
  id: string;
  points: number[];
  type: "ink" | "underline";
  width: number;
  color: string;
};

type UnderlineBurn = {
  strokeId: string;
  bluePath: number[];
  remainingPath: number[];
  width: number;
};

type SmartCrop = {
  x: number;
  y: number;
  width: number;
  height: number;
  averageLineHeight: number;
};

function App() {
  const holdTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastPointRef = useRef<{ x: number; y: number } | null>(null);
  const stageRef = useRef<Konva.Stage | null>(null);
  const activeStrokeRef = useRef<Stroke | null>(null);
  const drawingLayerRef = useRef<Konva.Layer | null>(null);
  const burnedStrokeIdRef = useRef<string | null>(null);

  const [tool, setTool] = useState<Tool>("pen");
  const [strokes, setStrokes] = useState<Stroke[]>([]);
  const [strokeWidth, setStrokeWidth] = useState(1.3);
  const [strokeColor, setStrokeColor] = useState("#111");
  const [isDrawing, setIsDrawing] = useState(false);
  const [underlineBurn, setUnderlineBurn] = useState<UnderlineBurn | null>(
    null,
  );
  const [burningStrokeId, setBurningStrokeId] = useState<string | null>(null);

  const cancelHoldTimer = () => {
    if (holdTimer.current) {
      clearTimeout(holdTimer.current);
      holdTimer.current = null;
    }
  };

  const getStrokeBounds = (stroke: Stroke) => {
    const xs = stroke.points.filter((_, i) => i % 2 === 0);
    const ys = stroke.points.filter((_, i) => i % 2 === 1);

    return {
      minX: Math.min(...xs),
      maxX: Math.max(...xs),
      minY: Math.min(...ys),
      maxY: Math.max(...ys),
    };
  };

  const getAverageLineHeight = (strokesToMeasure: Stroke[]) => {
    const heights = strokesToMeasure
      .map((stroke) => {
        const bounds = getStrokeBounds(stroke);
        return bounds.maxY - bounds.minY;
      })
      .filter((height) => height > 4);

    if (heights.length === 0) return 24;

    const sorted = [...heights].sort((a, b) => a - b);

    if (sorted.length > 4) {
      sorted.shift();
      sorted.pop();
    }

    return sorted.reduce((sum, height) => sum + height, 0) / sorted.length;
  };

  const getSmartCropForUnderline = (
    underline: Stroke,
    allStrokes: Stroke[],
  ): SmartCrop | null => {
    const underlineBounds = getStrokeBounds(underline);

    const paddingX = 16;
    const paddingY = 8;
    const lineGap = 36;

    const candidateStrokes = allStrokes
      .filter((stroke) => {
        if (stroke.id === underline.id) return false;
        if (stroke.type === "underline") return false;

        const bounds = getStrokeBounds(stroke);

        const horizontallyOverlaps =
          bounds.maxX >= underlineBounds.minX &&
          bounds.minX <= underlineBounds.maxX;

        const isAboveUnderline = bounds.maxY < underlineBounds.minY;

        return horizontallyOverlaps && isAboveUnderline;
      })
      .map((stroke) => {
        const bounds = getStrokeBounds(stroke);

        return {
          stroke,
          bounds,
          distanceFromUnderline: underlineBounds.minY - bounds.maxY,
        };
      })
      .sort((a, b) => a.distanceFromUnderline - b.distanceFromUnderline);

    if (candidateStrokes.length === 0) {
      console.log("No question strokes found above underline");
      return null;
    }

    const nearest = candidateStrokes[0];

    const questionStrokes = candidateStrokes.filter(
      (item) => Math.abs(item.bounds.maxY - nearest.bounds.maxY) <= lineGap,
    );

    const allBounds = questionStrokes.map((item) => item.bounds);

    const minX = Math.min(...allBounds.map((b) => b.minX));
    const maxX = Math.max(...allBounds.map((b) => b.maxX));
    const minY = Math.min(...allBounds.map((b) => b.minY));
    const maxY = Math.max(...allBounds.map((b) => b.maxY));

    return {
      x: minX - paddingX,
      y: minY - paddingY,
      width: maxX - minX + paddingX * 2,
      height: maxY - minY + paddingY * 2,
      averageLineHeight: getAverageLineHeight(
        questionStrokes.map((item) => item.stroke),
      ),
    };
  };

  const getCroppedImageBase64 = (crop: SmartCrop) => {
    const stage = stageRef.current;

    if (!stage) return null;

    return stage.toDataURL({
      x: crop.x,
      y: crop.y,
      width: crop.width,
      height: crop.height,
      pixelRatio: 2,
      mimeType: "image/png",
    });
  };

  const smoothPoints = (points: number[]) => {
    if (points.length < 6) return points;

    const smoothed = [points[0], points[1]];

    for (let i = 2; i < points.length - 2; i += 2) {
      const prevX = points[i - 2];
      const prevY = points[i - 1];
      const x = points[i];
      const y = points[i + 1];
      const nextX = points[i + 2];
      const nextY = points[i + 3];

      smoothed.push(
        prevX * 0.25 + x * 0.5 + nextX * 0.25,
        prevY * 0.25 + y * 0.5 + nextY * 0.25,
      );
    }

    smoothed.push(points[points.length - 2], points[points.length - 1]);

    return smoothed;
  };

  const renderSmoothStroke = (stroke: Stroke) => (
    <Shape
      key={stroke.id}
      sceneFunc={(context, shape) => {
        const points = smoothPoints(stroke.points);

        if (points.length < 4) return;

        context.beginPath();
        context.moveTo(points[0], points[1]);

        for (let i = 2; i < points.length - 2; i += 2) {
          const currentX = points[i];
          const currentY = points[i + 1];
          const nextX = points[i + 2];
          const nextY = points[i + 3];

          context.quadraticCurveTo(
            currentX,
            currentY,
            (currentX + nextX) / 2,
            (currentY + nextY) / 2,
          );
        }

        context.lineTo(points[points.length - 2], points[points.length - 1]);
        context.strokeShape(shape);
      }}
      stroke={stroke.type === "underline" ? "#2563eb" : stroke.color}
      strokeWidth={stroke.width}
      lineCap="round"
      lineJoin="round"
    />
  );

  const detectUnderline = (stroke: Stroke) => {
    const bounds = getStrokeBounds(stroke);
    const width = bounds.maxX - bounds.minX;
    const height = bounds.maxY - bounds.minY;

    return width > 100 && height < 20;
  };

  const askAiWithCrop = async (crop: SmartCrop, underline: Stroke) => {
    try {
      console.log("askAiWithCrop started");
      console.log("crop:", crop);
      console.log("underline:", underline);
      const imageBase64 = getCroppedImageBase64(crop);

      if (!imageBase64) {
        console.error("Could not capture cropped image");
        return;
      }

      const underlineBounds = getStrokeBounds(underline);

      const response = await fetch("http://192.168.1.66:3001/api/ai/ask", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          prompt:
            "Read the handwritten question in this image and answer it directly. Return answer strokes.",
          imageBase64,
          underline,
          placement: {
            x: underlineBounds.minX,
            y: underlineBounds.maxY + crop.averageLineHeight * 1.6,
            averageLineHeight: crop.averageLineHeight,
            width: underline.width,
            color: underline.color,
          },
        }),
      });

      console.log("fetch returned:", response.status);
      const data = await response.json();
      if (Array.isArray(data.strokes)) {
        setStrokes((prev) => [...prev, ...data.strokes]);
      }

      console.log("AI response:", data);
    } catch (error) {
      console.error("askAiWithCrop failed", error);
    }
  };

  const animateUnderlineBurn = (underline: Stroke) => {
    const points = underline.points;
    burnedStrokeIdRef.current = underline.id;
    setBurningStrokeId(underline.id);

    let i = 2;

    const interval = setInterval(() => {
      if (i >= points.length) {
        clearInterval(interval);

        setUnderlineBurn({
          strokeId: underline.id,
          bluePath: points,
          remainingPath: [],
          width: underline.width,
        });

        setTimeout(() => {
          setUnderlineBurn(null);
          setBurningStrokeId(null);
          activeStrokeRef.current = null;
          drawingLayerRef.current?.batchDraw();
        }, 250);

        return;
      }

      setUnderlineBurn({
        strokeId: underline.id,
        bluePath: points.slice(0, i),
        remainingPath: points.slice(i),
        width: underline.width,
      });

      i += 6;
    }, 16);
  };

  const startHoldTimer = () => {
    if (holdTimer.current) return;

    holdTimer.current = setTimeout(() => {
      const underline = activeStrokeRef.current;

      if (!underline) return;
      if (!detectUnderline(underline)) return;

      console.log("Underline hold detected");
      animateUnderlineBurn(underline);
      const crop = getSmartCropForUnderline(underline, strokes);

      if (!crop) return;

      askAiWithCrop(crop, underline);
    }, 2000);
  };

  const startDrawing = (e: any) => {
    cancelHoldTimer();
    e.evt.preventDefault();

    if (tool !== "pen") return;

    const stage = e.target.getStage();
    const point = stage?.getPointerPosition();

    if (!point) return;

    lastPointRef.current = point;
    setIsDrawing(true);

    activeStrokeRef.current = {
      id: `${Date.now()}-${Math.random()}`,
      points: [point.x, point.y],
      type: "ink",
      width: strokeWidth,
      color: strokeColor,
    };
  };

  const draw = (e: any) => {
    e.evt.preventDefault();

    const stage = e.target.getStage();
    const point = stage.getPointerPosition();

    if (!point) return;

    if (tool === "eraser") {
      setStrokes((prev) =>
        prev.filter((stroke) => {
          for (let i = 0; i < stroke.points.length; i += 2) {
            const x = stroke.points[i];
            const y = stroke.points[i + 1];

            if (Math.hypot(point.x - x, point.y - y) < 18) {
              return false;
            }
          }

          return true;
        }),
      );

      return;
    }

    if (!isDrawing || !activeStrokeRef.current) return;

    const updatedStroke: Stroke = {
      ...activeStrokeRef.current,
      points: activeStrokeRef.current.points.concat([point.x, point.y]),
    };

    activeStrokeRef.current = updatedStroke;
    drawingLayerRef.current?.batchDraw();

    const lastPoint = lastPointRef.current;

    if (lastPoint) {
      const distance = Math.hypot(point.x - lastPoint.x, point.y - lastPoint.y);
      const looksLikeUnderline = detectUnderline(updatedStroke);

      if (looksLikeUnderline && distance < 3) {
        startHoldTimer();
      } else {
        cancelHoldTimer();
      }
    }

    lastPointRef.current = point;
  };

  const stopDrawing = () => {
    cancelHoldTimer();

    const finishedStroke = activeStrokeRef.current;

    if (finishedStroke && finishedStroke.id !== burnedStrokeIdRef.current) {
      setStrokes((prev) => [...prev, finishedStroke]);
    }

    lastPointRef.current = null;
    activeStrokeRef.current = null;
    burnedStrokeIdRef.current = null;
    setIsDrawing(false);
  };

  const renderPathShape = (
    points: number[],
    color: string,
    width: number,
    glow = false,
  ) => (
    <Shape
      sceneFunc={(context, shape) => {
        const smoothed = smoothPoints(points);

        if (smoothed.length < 4) return;

        context.beginPath();
        context.moveTo(smoothed[0], smoothed[1]);

        for (let i = 2; i < smoothed.length - 2; i += 2) {
          const x = smoothed[i];
          const y = smoothed[i + 1];
          const nextX = smoothed[i + 2];
          const nextY = smoothed[i + 3];

          context.quadraticCurveTo(x, y, (x + nextX) / 2, (y + nextY) / 2);
        }

        context.lineTo(
          smoothed[smoothed.length - 2],
          smoothed[smoothed.length - 1],
        );
        context.strokeShape(shape);
      }}
      stroke={color}
      strokeWidth={width}
      lineCap="round"
      lineJoin="round"
      shadowColor={glow ? color : undefined}
      shadowBlur={glow ? 14 : 0}
      opacity={glow ? 0.95 : 1}
    />
  );

  return (
    <div className="app">
      <nav className="navbar">
        <div className="brand">Margin</div>

        <div className="toolbar">
          <button
            className={`toolButton ${tool === "pen" ? "active" : ""}`}
            onClick={() => setTool("pen")}
          >
            ✏️
          </button>

          <button
            className={`toolButton ${tool === "eraser" ? "active" : ""}`}
            onClick={() => setTool("eraser")}
          >
            🧽
          </button>
        </div>
      </nav>

      <main className="workspace">
        <section className="notePage">
          <div className="paperLines"></div>

          <Stage
            ref={stageRef}
            className="canvasLayer"
            width={794}
            height={1123}
            onMouseDown={startDrawing}
            onMouseMove={draw}
            onMouseUp={stopDrawing}
            onTouchStart={startDrawing}
            onTouchMove={draw}
            onTouchEnd={stopDrawing}
          >
            <Layer ref={drawingLayerRef}>
              {strokes.map((stroke) => renderSmoothStroke(stroke))}

              <Shape
                sceneFunc={(context, shape) => {
                  const stroke = activeStrokeRef.current;

                  if (
                    !stroke ||
                    stroke.id === burningStrokeId ||
                    stroke.points.length < 4
                  ) {
                    return;
                  }

                  const points = smoothPoints(stroke.points);

                  context.beginPath();
                  context.moveTo(points[0], points[1]);

                  for (let i = 2; i < points.length - 2; i += 2) {
                    const x = points[i];
                    const y = points[i + 1];
                    const nextX = points[i + 2];
                    const nextY = points[i + 3];

                    context.quadraticCurveTo(
                      x,
                      y,
                      (x + nextX) / 2,
                      (y + nextY) / 2,
                    );
                  }

                  context.lineTo(
                    points[points.length - 2],
                    points[points.length - 1],
                  );
                  context.strokeShape(shape);
                }}
                stroke={activeStrokeRef.current?.color ?? "#111"}
                strokeWidth={activeStrokeRef.current?.width ?? strokeWidth}
                lineCap="round"
                lineJoin="round"
              />

              {underlineBurn &&
                underlineBurn.remainingPath.length >= 4 &&
                renderPathShape(
                  underlineBurn.remainingPath,
                  "#111",
                  underlineBurn.width,
                )}

              {underlineBurn &&
                underlineBurn.bluePath.length >= 4 &&
                renderPathShape(
                  underlineBurn.bluePath,
                  "#38bdf8",
                  underlineBurn.width,
                  true,
                )}
            </Layer>
          </Stage>
        </section>
      </main>
    </div>
  );
}

export default App;
