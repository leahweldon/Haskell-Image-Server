module Render
  ( Window(..)
  , defaultWindow
  , sampleCoordinate
  , pixelToPoint
  , insideDrawing
  , colorPixel
  , render
  , rgbRender
  ) where

import Codec.Picture (PixelRGB8(..), PixelRGBA8(..), generateImage, writePng)
import Control.Monad (when)
import Shapes

data Window = Window Point Point (Int, Int)
  deriving (Show)

defaultWindow :: Window
defaultWindow = Window (point (-10) (-10)) (point 10 10) (500, 500)

sampleCoordinate :: Int -> Double -> Double -> Int -> Double
sampleCoordinate _ start end count | count <= 1 = (start + end) / 2
sampleCoordinate index start end count =
  start + (end - start) * fromIntegral index / fromIntegral (count - 1)

pixelToPoint :: Window -> (Int, Int) -> Point
pixelToPoint (Window lower upper (width, height)) (x, y) =
  point (sampleCoordinate x (getX lower) (getX upper) width)
        (sampleCoordinate (height - 1 - y) (getY lower) (getY upper) height)

contains :: Point -> (Transform, Shape, Color) -> Bool
contains worldPoint (transformation, shape, _) =
  maybe False (`within` shape) (inverseTransform transformation worldPoint)

insideDrawing :: Point -> Drawing -> Bool
insideDrawing worldPoint = any (contains worldPoint)

-- Drawing order follows the eDSL: the first shape appears above later shapes.
colorPixel :: Point -> Drawing -> Color
colorPixel worldPoint = foldr composite transparent
  where
    composite layer@(_, _, colour) below
      | contains worldPoint layer = sourceOver colour below
      | otherwise = below

validateWindow :: Window -> IO ()
validateWindow (Window _ _ (width, height)) =
  when (width <= 0 || height <= 0) $
    ioError (userError "Image width and height must be positive")

render :: FilePath -> Window -> Drawing -> IO ()
render filePath window@(Window _ _ (width, height)) drawing = do
  validateWindow window
  writePng filePath $ generateImage pixel width height
  where
    pixel x y = PixelRGB8 channel channel channel
      where
        channel = if insideDrawing (pixelToPoint window (x, y)) drawing then 255 else 0

rgbRender :: FilePath -> Window -> Drawing -> IO ()
rgbRender filePath window@(Window _ _ (width, height)) drawing = do
  validateWindow window
  writePng filePath $ generateImage pixel width height
  where
    pixel x y = PixelRGBA8 redChannel greenChannel blueChannel alphaChannel
      where
        Color redChannel greenChannel blueChannel alphaChannel =
          colorPixel (pixelToPoint window (x, y)) drawing
