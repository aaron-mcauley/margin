import { useRef, useState } from "react";
import { Stage, Layer, Line } from "react-konva";
import type Konva from "konva";
import "./App.scss";

type Tool = "pen" | "eraser";

type Stroke = {
  id: string;
  points: number[];
  type: "ink" | "underline";
};

function App() {
  const holdTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastPointRef = useRef<{ x: number; y: number } | null >(null);
  const stageRef = useRef<Konva.Stage | null>(null);
  const activeStrokeRef = useRef<Stroke | null>(null);
  const [tool, setTool] = useState<Tool>("pen");
  const [strokes, setStrokes] = useState<Stroke[]>([]);
  const [isDrawing, setIsDrawing] = useState(false);
  const [aiAnswer, setAiAnswer] = useState("");

  const cancelHoldTimer = () => {
  if(holdTimer.current) {
    clearTimeout(holdTimer.current);
    holdTimer.current = null;
  }
  }

  const getStrokeBounds = (stroke: Stroke) => {
  const xs = stroke.points.filter((_, i) => i % 2 === 0);
  const ys = stroke.points.filter((_,i) => i % 2 === 1);
  
  return {
    minX: Math.min(...xs),
    maxX: Math.max(...xs),
    minY: Math.min(...ys),
    maxY: Math.max(...ys),
  };
  };

  const getSmartCropForUnderline = (
  underline: Stroke,
   allStrokes: Stroke[]
  ) => {
  const underlineBounds = getStrokeBounds(underline);

  const paddingX = 16;
  const paddingY = 8;
  const lineGap = 36;

  const candidateStrokes = allStrokes
    .filter((stroke) => {
      if (stroke.id === underline.id)
        return false;

      if (stroke.type === "underline")
        return false;

      const bounds = getStrokeBounds(stroke);

      const horizontallyOverlaps = 
        bounds.maxX >= underlineBounds.minX &&
        bounds.minX <= underlineBounds.maxX;

      const isAboveUnderline = bounds.maxY < underlineBounds.minY;

      return horizontallyOverlaps && isAboveUnderline;
    })
    .map((stroke) => ({
      stroke,
      bounds: getStrokeBounds(stroke),
      distanceFromUnderline: underlineBounds.minY - getStrokeBounds(stroke).maxY,
    }))
    .sort((a,b) => a.distanceFromUnderline - b.distanceFromUnderline);

    if (candidateStrokes.length === 0) {
      console.log("No question strokes found above underline");
      return null;
    }

    const nearest = candidateStrokes[0];

    const questionStrokes = candidateStrokes.filter(
      (item) => Math.abs(item.bounds.maxY - nearest.bounds.maxY) <= lineGap
    );

    const allBounds = questionStrokes.map((item) => item.bounds);

    const minX = Math.min(...allBounds.map((b) => b.minX));
    const maxX = Math.max(...allBounds.map((b) => b.maxX));
    const minY = Math.min(...allBounds.map((b) => b.minY));
    const maxY = Math.max(...allBounds.map((b) => b.maxY));
    
    const crop = {
      x: minX - paddingX, 
      y: minY - paddingY,
      width: maxX - minX + paddingX * 2,
      height: maxY - minY + paddingY * 2,
    };

    console.log("Nearest-line crop:", crop);
    console.log("Question strokes found:", questionStrokes.length);

  return crop;
  };

  const getCroppedImageBase64 = (crop: {
  x: number;
  y: number;
  width: number;
  height: number;
}) => {
  const stage = stageRef.current;

  if (!stage)
    return null;

  return stage.toDataURL({
    x: crop.x,
    y: crop.y,
    width: crop.width,
    height: crop.height,
    pixelRatio: 2,
    mimeType: "image/png",
  });
  };

  const startHoldTimer = () => {
  console.log("Hold timer started");

  if (holdTimer.current) return;

  holdTimer.current = setTimeout(() => {
    console.log("2 seconds elapsed");

    const underline = activeStrokeRef.current;

    if (!underline) return;

    if (!detectUnderline(underline)) return;

    console.log("Underline hold detected");

    const crop = getSmartCropForUnderline(underline, strokes);

    if (!crop) return;

    setStrokes((prev) => {
      const next = [...prev];
      const lastIndex = next.findIndex((stroke) => stroke.id === underline.id);

      if (lastIndex === -1) return prev;

      next[lastIndex] = {
        ...next[lastIndex],
        type: "underline",
      };

      return next;
    });

    askAiWithCrop(crop);
  }, 2000);
};

  const askAiWithCrop = async (crop: {
  x: number;
  y: number;
  width: number;
  height: number;
}) => {
  try {
    setAiAnswer("Reading underline...");

    const imageBase64 = getCroppedImageBase64(crop);
    console.log("2 image captured", imageBase64?.length);

    if (!imageBase64) {
      setAiAnswer("Could not capture cropped image.");
      return;
    }
    console.log("3 before fetch");

    const response = await fetch("http://192.168.1.66:3001/api/ai/ask", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        prompt:
          "Read the handwritten question in this image and answer it directly. Ignore any partial writing from nearby lines.",
        imageBase64,
      }),
    });

    console.log("4 fetch returned", response.status);
    const data = await response.json();
    console.log("5 json parsed", data);  
    setAiAnswer(data.answer ?? data.error ?? "No response");
  } catch (error) {
    console.error("askAIWithCrop failed", error);
    setAiAnswer(error instanceof Error ? error.message : "AI request failed");
  }
  };

  const startDrawing = (e: any) => {
  cancelHoldTimer();
  e.evt.preventDefault();
  
  if (tool !== "pen") 
    return;
  
  const stage = e.target.getStage();
  const point = stage?.getPointerPosition();
  
  if (!point) 
    return;
  
  lastPointRef.current = point;
  setIsDrawing(true);

  const newStroke: Stroke = {
    id: `${Date.now()} - ${Math.random()}`,
    points: [point.x, point.y],
    type: "ink",
  };
  activeStrokeRef.current = newStroke;
  setStrokes((prev) => [...prev, newStroke])
  };

  const draw = (e: any) => {
  e.evt.preventDefault();

  const stage = e.target.getStage();
  const point = stage.getPointerPosition();

  if (!point) return;

  if (tool === "eraser") {
    setStrokes((prev) =>
      prev.filter((stroke) => {
        for (let ii = 0; ii < stroke.points.length; ii += 2) {
          const x = stroke.points[ii];
          const y = stroke.points[ii + 1];

          if (Math.hypot(point.x - x, point.y - y) < 18) {
            return false;
          }
        }
        return true;
      })
    );

    return;
  }

  if (!isDrawing || !activeStrokeRef.current)
     return;

  const updatedStroke: Stroke = {
    ...activeStrokeRef.current,
    points: activeStrokeRef.current.points.concat([point.x,point.y]),
  };

  activeStrokeRef.current = updatedStroke;

  setStrokes((prev) => {
    const next = [...prev];
    next[next.length - 1] = updatedStroke;

    return next;
  });

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

  const detectUnderline = (stroke: Stroke) => {
    const xs = stroke.points.filter((_, i) => i % 2 === 0);
    const ys = stroke.points.filter((_, i) => i % 2 === 1);

    const width = Math.max(...xs) - Math.min(...xs);
    const height = Math.max(...ys) - Math.min(...ys);
    console.log("underline metrics", { width, height });
    return width > 100 && height < 20;
  };

  const stopDrawing = () => {
    cancelHoldTimer();
    lastPointRef.current = null;
    activeStrokeRef.current = null;
    setIsDrawing(false);
  };

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
      
      {aiAnswer && <div className="aiResponse">{aiAnswer}</div>}
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
            <Layer>
              {strokes.map((stroke) => (
                <Line
                  key={stroke.id}
                  points={stroke.points}
                  stroke={stroke.type === "underline" ? "#2563eb" : "#111"}
                  strokeWidth={4}
                  tension={0.5}
                  lineCap="round"
                  lineJoin="round"
                />
              ))}
            </Layer>
          </Stage>
        </section>
      </main>
    </div>
  );
}

export default App;
