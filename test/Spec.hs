module Main (main) where

import Codec.Picture
  ( PixelRGBA8(..)
  , convertRGBA8
  , imageHeight
  , imageWidth
  , pixelAt
  , readPng
  )
import Control.Exception (finally)
import Control.Monad (unless)
import System.Directory (getTemporaryDirectory, removeFile)
import System.IO (hClose, openTempFile)
import Render
import Shapes

assert :: String -> Bool -> IO ()
assert label condition = unless condition (error ("Test failed: " ++ label))

near :: Double -> Double -> Bool
near x y = abs (x - y) < 1e-9

nearPoint :: Point -> Point -> Bool
nearPoint expected actual =
  near (getX expected) (getX actual)
    && near (getY expected) (getY actual)

assertPoint :: String -> Point -> Point -> IO ()
assertPoint label expected actual = assert label (nearPoint expected actual)

assertInverse :: String -> Transform -> Point -> IO ()
assertInverse label operation pointToTransform =
  case inverseTransform operation (transform operation pointToTransform) of
    Nothing -> error ("Test failed: " ++ label ++ " has no inverse")
    Just actual -> assertPoint label pointToTransform actual

main :: IO ()
main = do
  assert "circle contains centre" (within (point 0 0) circle)
  assert "circle excludes distant point" (not $ within (point 1.1 0) circle)
  assert "empty contains nothing" (not $ within (point 0 0) empty)
  assert "rectangle aspect ratio" (within (point 1.5 0.5) (rectangle 2 1))
  assert "rectangle outside" (not $ within (point 2.1 0) (rectangle 2 1))
  assert "ellipse inside" (within (point 1.5 0) (ellipse 2 1))
  assert "ellipse outside" (not $ within (point 2.1 0) (ellipse 2 1))
  let triangle = polygon [point 0 0, point 2 0, point 0 2]
  assert "polygon interior" (within (point 0.5 0.5) triangle)
  assert "polygon boundary" (within (point 1 0) triangle)
  assert "polygon exterior" (not $ within (point 2 2) triangle)
  assert "empty polygon" (not $ within (point 0 0) (polygon []))
  assert "degenerate polygon" (not $ within (point 0 0) (polygon [point 0 0, point 1 1]))

  assertPoint "translation" (point 4 3) (transform (translate (point 2 1)) (point 2 2))
  assertPoint "rotation degrees" (point 0 1) (transform (rotate 90) (point 1 0))
  assertPoint "scale" (point 6 4) (transform (scale (point 3 2)) (point 2 2))
  assertPoint "shear" (point 4 2) (transform (shear 1) (point 2 2))
  assertInverse "translation inverse" (translate (point (-4) 3)) (point 1 2)
  assertInverse "scale inverse" (scale (point 2 0.5)) (point 1 2)
  assertInverse "rotation inverse" (rotate 30) (point 1 2)
  assertInverse "shear inverse" (shear 0.5) (point 1 2)
  assertInverse "composed inverse" (scale (point 2 3) <+> rotate 30 <+> translate (point 1 4)) (point 1 2)
  assert "singular scale cannot be inverted" (inverseTransform (scale (point 0 2)) (point 0 0) == Nothing)

  let shifted = [(translate (point 3 0), circle, red)]
  assert "drawn shape follows positive translation" (insideDrawing (point 3 0) shifted)
  assert "shifted shape no longer at origin" (not $ insideDrawing (point 0 0) shifted)
  let opaqueLayers = [(identity, circle, red), (identity, circle, blue)]
  assert "front layer visible" (colorPixel (point 0 0) opaqueLayers == red)
  assert "empty pixel transparent" (a (colorPixel (point 5 5) opaqueLayers) == 0)
  let blended = [(identity, circle, Color 255 0 0 128), (identity, circle, blue)]
  assert "transparent source-over blending" (colorPixel (point 0 0) blended == Color 128 0 127 255)
  assert "switchingLayer places top drawing first"
    (colorPixel (point 0 0) (switchingLayer 128 [(identity, circle, blue)] [(identity, circle, red)])
      == Color 128 0 127 255)

  let window = Window (point (-10) (-10)) (point 10 10) (3, 3)
  assertPoint "top-left pixel" (point (-10) 10) (pixelToPoint window (0, 0))
  assertPoint "bottom-right pixel" (point 10 (-10)) (pixelToPoint window (2, 2))
  assertPoint "centre pixel" (point 0 0) (pixelToPoint window (1, 1))

  temporary <- getTemporaryDirectory
  (temporaryPath, handle) <- openTempFile temporary "haskell-image-server.png"
  hClose handle
  (do
      rgbRender temporaryPath (Window (point (-1) (-1)) (point 1 1) (3, 3))
        [(identity, circle, red)]
      decoded <- readPng temporaryPath
      case decoded of
        Left err -> error ("Test failed: PNG decoding: " ++ err)
        Right dynamic -> do
          let picture = convertRGBA8 dynamic
          assert "image dimensions" (imageWidth picture == 3 && imageHeight picture == 3)
          assert "centre pixel colour" (pixelAt picture 1 1 == PixelRGBA8 255 0 0 255)
          assert "transparent corner" (pixelAt picture 0 0 == PixelRGBA8 255 255 255 0)
    ) `finally` removeFile temporaryPath

  putStrLn "All geometry, transformation, layering and rendering tests passed."
