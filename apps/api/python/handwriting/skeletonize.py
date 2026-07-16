import json
import sys
import cv2 
import numpy as np

def main():
    payload = json.loads(sys.stdin.read())

    width = payload["width"]
    height = payload["height"]
    pixels = payload["pixels"]

    #Reconstruct grayscale image
    image = np.array(pixels, dtype=np.uint8).reshape((height, width))

    #Convert to binary image
    _, binary = cv2.threshold(
        image,
        200,
        255,
        cv2.THRESH_BINARY_INV,
    )

    # Skeletonize (Zhang-Suen)
    skeleton = cv2.ximgproc.thinning(
        binary,
        thinningType=cv2.ximgproc.THINNING_ZHANGSUEN,
    )

    #Convert back to white background / black ink
    output = cv2.bitwise_not(skeleton)

    print(
        json.dumps(
            {
                "width": width,
                "height": height, 
                "pixels": output.flatten().tolist(),
            }
        )
    )

if __name__ == "__main__":
    main()