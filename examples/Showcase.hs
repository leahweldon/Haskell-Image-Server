module Main (main) where

-- Renders larger scenes with the drawing language to show rotation,
-- concave polygons and translucent layering working together.
--
--   stack exec showcase                  -- writes PNGs to docs/showcase/
--   stack exec showcase -- frames DIR    -- writes 120 frames of one full turn of the rosette

import Control.Monad (forM_)
import Data.Word (Word8)
import System.Environment (getArgs)
import Text.Printf (printf)
import System.Directory (createDirectoryIfMissing)
import Render (Window(..), rgbRender)
import Shapes

-- A colour wheel, sampled at an angle in degrees.
hue :: Word8 -> Double -> Color
hue alpha degrees = createColor (channel 0) (channel 120) (channel 240) alpha
  where
    channel offset =
      round (127.5 + 127.5 * cos ((degrees - offset) * pi / 180))

-- A square larger than the window, placed last so it sits behind everything.
background :: Drawing
background = [(scale (point 6 6), rectangle 1 1, createColor 17 24 39 255)]

-- Twelve translucent ellipses swept around the origin.
rosette :: Double -> Drawing
rosette turn =
  [ ( translate (point 1.5 0) <+> rotate angle
    , ellipse 3 1
    , hue 120 angle
    )
  | k <- [0 .. 11 :: Int]
  , let angle = turn + 30 * fromIntegral k
  ]

-- A five-pointed star is concave, so it exercises the even-odd fill rule.
star :: Double -> Double -> Shape
star outer inner = polygon
  [ point (radius * sin theta) (radius * cos theta)
  | k <- [0 .. 9 :: Int]
  , let theta = fromIntegral k * pi / 5
  , let radius = if even k then outer else inner
  ]

-- Three overlapping stars, each turned a little further than the last.
stars :: Drawing
stars =
  [ ( rotate (24 * fromIntegral k) <+> scale (point 3.4 3.4) <+> translate offset
    , star 1 0.42
    , hue 150 (120 * fromIntegral k + 20)
    )
  | (k, offset) <- zip [0 :: Int ..] [point 0 0.45, point (-0.4) (-0.25), point 0.4 (-0.25)]
  ]

window :: Int -> Window
window size = Window (point (-5) (-5)) (point 5 5) (size, size)

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["frames", dir] -> do
      createDirectoryIfMissing True dir
      forM_ [0 .. 119 :: Int] $ \i ->
        rgbRender (printf "%s/frame-%03d.png" dir i) (window 400)
          (rosette (3 * fromIntegral i) ++ background)
    _ -> do
      createDirectoryIfMissing True "docs/showcase"
      rgbRender "docs/showcase/rosette.png" (window 800) (rosette 0 ++ background)
      rgbRender "docs/showcase/stars.png" (window 800) (stars ++ background)
