module Shapes
  ( Point
  , Vector(..)
  , vector
  , point
  , getX
  , getY
  , Shape(..)
  , Drawing
  , empty
  , circle
  , rectangle
  , ellipse
  , polygon
  , Transform(..)
  , Matrix(..)
  , matrix
  , identity
  , translate
  , scale
  , rotate
  , shear
  , (<+>)
  , transform
  , inverseTransform
  , within
  , insidePolygon
  , Color(..)
  , createColor
  , red
  , green
  , blue
  , pink
  , transparent
  , switchingLayer
  , sourceOver
  ) where

import Data.Word (Word8)

data Vector = Vector Double Double
  deriving (Eq, Show)

type Point = Vector

type Drawing = [(Transform, Shape, Color)]

data Shape
  = Empty
  | Circle
  | Rectangle Double
  | Ellipse Double
  | Polygon [Point]
  deriving (Show)

empty, circle :: Shape
empty = Empty
circle = Circle

-- Width and height determine the aspect ratio; the base half-height is one.
rectangle, ellipse :: Double -> Double -> Shape
rectangle width height = Rectangle (width / height)
ellipse width height = Ellipse (width / height)

polygon :: [Point] -> Shape
polygon = Polygon

data Matrix = Matrix Vector Vector
  deriving (Show)

data Transform
  = Identity
  | Translate Vector
  | Scale Vector
  | Rotate Matrix
  | Shear Double
  | Compose Transform Transform
  deriving (Show)

vector, point :: Double -> Double -> Point
vector = Vector
point = Vector

getX, getY :: Vector -> Double
getX (Vector x _) = x
getY (Vector _ y) = y

matrix :: Double -> Double -> Double -> Double -> Matrix
matrix a b c d = Matrix (Vector a b) (Vector c d)

identity :: Transform
identity = Identity

translate :: Point -> Transform
translate = Translate

scale :: Point -> Transform
scale = Scale

-- Angles are expressed in degrees.
rotate :: Double -> Transform
rotate degrees = Rotate $ matrix (cos angle) (-sin angle) (sin angle) (cos angle)
  where angle = degrees * pi / 180

shear :: Double -> Transform
shear = Shear

infixl 6 <+>
(<+>) :: Transform -> Transform -> Transform
(<+>) = Compose

transform :: Transform -> Point -> Point
transform Identity p = p
transform (Translate (Vector tx ty)) (Vector x y) = Vector (x + tx) (y + ty)
transform (Scale (Vector sx sy)) (Vector x y) = Vector (x * sx) (y * sy)
transform (Rotate m) p = multiply m p
transform (Shear factor) (Vector x y) = Vector (x + factor * y) y
transform (Compose first second) p = transform second (transform first p)

multiply :: Matrix -> Vector -> Vector
multiply (Matrix (Vector a b) (Vector c d)) (Vector x y) =
  Vector (a * x + b * y) (c * x + d * y)

-- Rasterisation samples world coordinates and maps them into local shape space.
inverseTransform :: Transform -> Point -> Maybe Point
inverseTransform Identity p = Just p
inverseTransform (Translate (Vector tx ty)) (Vector x y) = Just (Vector (x - tx) (y - ty))
inverseTransform (Scale (Vector sx sy)) (Vector x y)
  | sx == 0 || sy == 0 = Nothing
  | otherwise = Just (Vector (x / sx) (y / sy))
inverseTransform (Rotate (Matrix (Vector a b) (Vector c d))) (Vector x y)
  | abs determinant < 1e-12 = Nothing
  | otherwise = Just (Vector ((d * x - b * y) / determinant) ((a * y - c * x) / determinant))
  where determinant = a * d - b * c
inverseTransform (Shear factor) (Vector x y) = Just (Vector (x - factor * y) y)
inverseTransform (Compose first second) p =
  inverseTransform second p >>= inverseTransform first

within :: Point -> Shape -> Bool
within _ Empty = False
within (Vector x y) Circle = x * x + y * y <= 1
within (Vector x y) (Rectangle ratio) = ratio > 0 && abs x <= ratio && abs y <= 1
within (Vector x y) (Ellipse ratio) = ratio > 0 && x * x / (ratio * ratio) + y * y <= 1
within p (Polygon vertices) = insidePolygon p vertices

-- The even-odd rule supports both convex and concave polygons.
insidePolygon :: Point -> [Point] -> Bool
insidePolygon _ [] = False
insidePolygon _ [_] = False
insidePolygon _ [_, _] = False
insidePolygon (Vector px py) vertices =
  any onEdge edges || odd (length (filter crossesRay edges))
  where
    edges = zip vertices (tail vertices ++ [head vertices])
    onEdge (Vector x1 y1, Vector x2 y2) =
      abs ((px - x1) * (y2 - y1) - (py - y1) * (x2 - x1)) <= 1e-9
        && px >= min x1 x2 - 1e-9 && px <= max x1 x2 + 1e-9
        && py >= min y1 y2 - 1e-9 && py <= max y1 y2 + 1e-9
    crossesRay (Vector x1 y1, Vector x2 y2) =
      (y1 > py) /= (y2 > py)
        && px < x1 + (py - y1) * (x2 - x1) / (y2 - y1)

data Color = Color
  { r :: Word8
  , g :: Word8
  , b :: Word8
  , a :: Word8
  } deriving (Eq, Show)

createColor :: Word8 -> Word8 -> Word8 -> Word8 -> Color
createColor = Color

red, green, blue, pink, transparent :: Color
red = Color 255 0 0 255
green = Color 0 255 0 255
blue = Color 0 0 255 255
pink = Color 255 192 203 255
transparent = Color 255 255 255 0

-- The first drawing layer is in front; the supplied alpha applies to the top layer.
switchingLayer :: Word8 -> Drawing -> Drawing -> Drawing
switchingLayer opacity bottom top =
  [(t, shape, colour {a = opacity}) | (t, shape, colour) <- top] ++ bottom

-- Porter-Duff source-over compositing for non-premultiplied RGBA values.
sourceOver :: Color -> Color -> Color
sourceOver front back
  | a front == 0 = back
  | a front == 255 = front
  | otherwise = Color (blend r) (blend g) (blend b) (round (outAlpha * 255))
  where
    frontAlpha = fromIntegral (a front) / 255 :: Double
    backAlpha = fromIntegral (a back) / 255 :: Double
    outAlpha = frontAlpha + backAlpha * (1 - frontAlpha)
    blend channel = round
      ((fromIntegral (channel front) * frontAlpha
         + fromIntegral (channel back) * backAlpha * (1 - frontAlpha)) / outAlpha)
