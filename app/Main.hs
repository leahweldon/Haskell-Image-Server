{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (forM_)
import Data.List (find)
import Data.String (fromString)
import qualified Data.Text.Lazy as TL
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A
import Text.Blaze.Html5 ((!))
import qualified Text.Blaze.Html.Renderer.Text as R
import System.Directory (createDirectoryIfMissing)
import Web.Scotty (ActionM, file, get, html, next, param, scotty, setHeader)

import Render (defaultWindow, rgbRender)
import Shapes

data Example = Example
  { slug :: String
  , title :: String
  , family :: String
  , description :: String
  , expression :: String
  , drawing :: Drawing
  }

circleDrawing, rectangleDrawing, ellipseDrawing, polygonDrawing :: Drawing
circleDrawing = [(identity, circle, createColor 255 0 255 255)]
rectangleDrawing = [(identity, rectangle 2 1, createColor 0 0 255 255)]
ellipseDrawing = [(rotate 45, ellipse 2 1, createColor 255 0 0 255)]
polygonDrawing = [(identity, polygon [point (-2) 0, point 2 0, point 0 2], createColor 0 255 0 255)]

scaledCircle, scaledRectangle, rotatedEllipse, shearedRectangle, translatedCircle :: Drawing
scaledCircle = [(scale (point 0.2 0.2), circle, createColor 255 255 0 255)]
scaledRectangle = [(scale (point 1.6 0.7), rectangle 2 1, createColor 255 255 0 255)]
rotatedEllipse = [(rotate 30, ellipse 2 1, createColor 128 0 128 255)]
shearedRectangle = [(shear 0.5, rectangle 2 1, createColor 0 128 255 255)]
translatedCircle = [(translate (point (-6) 1), circle, createColor 255 165 0 255)]

move :: Point -> Drawing -> Drawing
move delta = map (\(t, shape, colour) -> (t <+> translate delta, shape, colour))

over, left, right, above, below :: Drawing -> Drawing -> Drawing
over top bottom = top ++ bottom
left first second = move (point (-4) 0) first ++ move (point 4 0) second
right first second = move (point 4 0) first ++ move (point (-4) 0) second
above first second = move (point 0 4) first ++ move (point 0 (-4)) second
below first second = move (point 0 (-4)) first ++ move (point 0 4) second

examples :: [Example]
examples =
  [ Example "circle" "Circle" "Primitive" "A filled circle using a solid RGBA colour."
      "[(identity, circle, createColor 255 0 255 255)]" circleDrawing
  , Example "rectangle" "Rectangle" "Primitive" "An axis-aligned rectangle with a 2:1 aspect ratio."
      "[(identity, rectangle 2 1, createColor 0 0 255 255)]" rectangleDrawing
  , Example "ellipse" "Ellipse" "Primitive" "An elliptical shape rotated by 45 degrees."
      "[(rotate 45, ellipse 2 1, createColor 255 0 0 255)]" ellipseDrawing
  , Example "polygon" "Polygon" "Primitive" "A triangle represented by three vertices."
      "[(identity, polygon [point (-2) 0, point 2 0, point 0 2], createColor 0 255 0 255)]" polygonDrawing
  , Example "scaledCircle" "Scaled circle" "Transformation" "Independent scaling of both axes."
      "[(scale (point 0.2 0.2), circle, createColor 255 255 0 255)]" scaledCircle
  , Example "scaledRectangle" "Scaled rectangle" "Transformation" "Anisotropic scaling of a rectangular primitive."
      "[(scale (point 1.6 0.7), rectangle 2 1, createColor 255 255 0 255)]" scaledRectangle
  , Example "rotatedEllipse" "Rotated ellipse" "Transformation" "Rotation of an ellipse by 30 degrees."
      "[(rotate 30, ellipse 2 1, createColor 128 0 128 255)]" rotatedEllipse
  , Example "shearedRectangle" "Sheared rectangle" "Transformation" "Horizontal shear applied to a rectangle."
      "[(shear 0.5, rectangle 2 1, createColor 0 128 255 255)]" shearedRectangle
  , Example "translatedCircle" "Translated circle" "Transformation" "A circle shifted six units to the left and one up."
      "[(translate (point (-6) 1), circle, createColor 255 165 0 255)]" translatedCircle
  , Example "circleOverRectangle" "Circle over rectangle" "Composition" "The first drawing takes precedence where shapes overlap."
      "over circleDrawing rectangleDrawing" (over circleDrawing rectangleDrawing)
  , Example "circleLeftOfRectangle" "Circle left of rectangle" "Composition" "Two drawings placed side by side."
      "left circleDrawing rectangleDrawing" (left circleDrawing rectangleDrawing)
  , Example "polygonLeftOfRectangle" "Polygon left of rectangle" "Composition" "A triangle and rectangle arranged horizontally."
      "left polygonDrawing rectangleDrawing" (left polygonDrawing rectangleDrawing)
  , Example "circleRightOfRectangle" "Circle right of rectangle" "Composition" "Right-aligned circle relative to a rectangle."
      "right circleDrawing rectangleDrawing" (right circleDrawing rectangleDrawing)
  , Example "circleAboveRectangle" "Circle above rectangle" "Composition" "Two primitives stacked vertically."
      "above circleDrawing rectangleDrawing" (above circleDrawing rectangleDrawing)
  , Example "rectangleAboveEllipse" "Rectangle above ellipse" "Composition" "A vertical arrangement using the above operator."
      "above rectangleDrawing ellipseDrawing" (above rectangleDrawing ellipseDrawing)
  , Example "rectangleBelowEllipse" "Rectangle below ellipse" "Composition" "A vertical arrangement using the below operator."
      "below rectangleDrawing ellipseDrawing" (below rectangleDrawing ellipseDrawing)
  , Example "colourLayers" "Translucent layers" "Composition" "Source-over alpha blending of two overlapping shapes."
      "switchingLayer 128 rectangleDrawing circleDrawing"
      (switchingLayer 128 rectangleDrawing circleDrawing)
  ]

imageUrl :: Example -> String
imageUrl item = "/images/" ++ slug item ++ ".png"

imagePath :: Example -> FilePath
imagePath item = "generated/" ++ slug item ++ ".png"

card :: Example -> H.Html
card item = H.article ! A.class_ "card" $ do
  H.a ! A.class_ "preview" ! A.href (fromString (imageUrl item)) $ do
    H.img ! A.src (fromString (imageUrl item)) ! A.alt (fromString (title item))
  H.div ! A.class_ "card-details" $ do
    H.p ! A.class_ "category" $ H.toHtml (family item)
    H.h3 $ H.toHtml (title item)
    H.p ! A.class_ "description" $ H.toHtml (description item)
    H.pre $ H.code $ H.toHtml (expression item)

galleryPage :: TL.Text
galleryPage = R.renderHtml $ H.docTypeHtml $ do
  H.head $ do
    H.meta ! A.charset "utf-8"
    H.meta ! A.name "viewport" ! A.content "width=device-width, initial-scale=1"
    H.title "Haskell Image Server | Drawing DSL"
    H.link ! A.rel "stylesheet" ! A.href "/style.css"
  H.body $ H.main ! A.class_ "shell" $ do
    H.header ! A.class_ "hero" $ do
      H.p ! A.class_ "eyebrow" $ "HASKELL / GENERATIVE GEOMETRY"
      H.h1 "Draw with code."
      H.p ! A.class_ "intro" $
        "An embedded domain-specific language for geometric primitives, transformations, layered colour and PNG rendering."
      H.div ! A.class_ "stats" $ do
        H.span "17 examples"
        H.span "2D affine transforms"
        H.span "Scotty + JuicyPixels"
    H.section ! A.class_ "gallery" $ forM_ examples card
    H.footer $ do
      H.p "CSU44012 · Topics in Functional Programming · Trinity College Dublin"
      H.p "Each image is rendered from the Haskell expression shown below it."

main :: IO ()
main = do
  createDirectoryIfMissing True "generated"
  forM_ examples $ \item -> rgbRender (imagePath item) defaultWindow (drawing item)
  scotty 3000 $ do
    get "/" $ html galleryPage
    get "/style.css" $ file "static/css/style.css"
    get "/images/:name" $ do
      requested <- param "name" :: ActionM TL.Text
      case find (\item -> TL.pack (slug item ++ ".png") == requested) examples of
        Just item -> do
          setHeader "Content-Type" "image/png"
          file (imagePath item)
        Nothing -> next
