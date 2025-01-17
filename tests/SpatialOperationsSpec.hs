{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}

module SpatialOperationsSpec where

import Test.Hspec
import qualified Data.ByteString as BS
import qualified Data.Vector as V
import Data.Geometry.Geos.Raw.Base
import Data.Geometry.Geos.Geometry
import Data.Geometry.Geos.Relatable
import Data.Geometry.Geos.Topology
import qualified Data.Geometry.Geos.STRTree as STR
import Data.Word

import SpecSampleData

spatialOpsSpecs = describe "Tests Contains" $ do
  it "Does polygon to point comparison" $ do
    let polygon         = makePolygonGeo [[(0,0), (0,1), (1,1), (1,0), (0,0)]]
        polygonWithHole = makePolygonGeo [ [(0,0), (0,1), (1,1), (1,0), (0,0)], [(0.1,0.1),(0.1,0.9),(0.9,0.1),(0.1,0.1)] ]
        pointIn         = makePointGeo (0.6, 0.6)
        pointOut        = makePointGeo (1.5, 0.5)
        pointInHole     = makePointGeo (0.4, 0.4)
    (contains polygon pointIn) `shouldBe` True
    (contains polygon pointOut) `shouldBe` False
    (contains polygonWithHole pointIn) `shouldBe` True
    (contains polygonWithHole pointOut) `shouldBe` False
    (contains polygonWithHole pointInHole) `shouldBe` False

  it "Does simple polygon to polygon comparison" $ do
    let polygonBig   = makePolygonGeo [ [(0,0), (0,2), (2,2), (2,0), (0,0)] ]
        polygonSmall = makePolygonGeo [ [(0,0), (0,1), (1,1), (1,0), (0,0)] ]
        polygonIntersect = makePolygonGeo [ [(0,0), (0,2.5), (1,1), (1,0), (0,0)] ]
    (contains polygonBig polygonSmall) `shouldBe` True
    (contains polygonBig polygonBig) `shouldBe` True
    (contains polygonBig polygonIntersect) `shouldBe` False

  it "Does multi polygon to point comparison" $ do
    let polygonBig   = [ [(0,0), (0,2), (2,2), (2,0), (0,0)]]
        polygonSmall = [ [(3,0), (3,1), (4,1), (4,0), (3,0)]]
        multiPoly    = makeMultiPolygonGeo [polygonBig, polygonSmall]
        pointIn      = makePointGeo (0.5, 0.5)
        pointOut     = makePointGeo (2.5, 0.5)
    (contains multiPoly pointIn) `shouldBe` True
    (contains multiPoly pointOut) `shouldBe` False
  it "Projects a point against a linestring" $ do
      let lr = makeLineStringGeo [(0,0), (0, 1), (1, 1)]
          p = makePointGeo (0.5, 1.0)
-- The point on this line string nearest (0.5, 1.0) is 1.5 units from the origin. i.e., halfway between the second and third point.
      project lr p `shouldBe` 1.5
      interpolate lr 1.5 `shouldBe` p
      projectNormalized lr p `shouldBe` 0.75
      interpolateNormalized lr 0.75 `shouldBe` p
  it "Tests disjoint geometries" $ do
    let poly = makePolygonGeo [[(0,0), (0,1), (1,1), (1,0), (0,0)]]
        p1 = makePointGeo (2,2)
        p2 = makePointGeo (0.5, 0.5)
    disjoint poly p1 `shouldBe` True
    disjoint poly p2 `shouldBe` False
  it "creates an envelope / boundary of a geometry" $ do
    let poly1 = makePolygonGeo [[(0,0), (0,1), (1,1), (1.5, 1.5), (1,0), (0,0)]]
        env1 = makePolygonGeo [[(0.0, 0.0), (1.5, 0.0), (1.5, 1.5), (0.0, 1.5), (0.0, 0.0)]]
        poly2 = makePolygonGeo [ [(0,0), (0,1), (1,1), (1,0), (0,0)], [(0.1,0.1),(0.1,0.9),(0.9,0.1),(0.1,0.1)] ]
        env2 = makeMultiLineStringGeo [[(0.0, 0.0), (0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)], [(0.1, 0.1), (0.1, 0.9), (0.9, 0.1), (0.1, 0.1)]]
        env3 = makePolygonGeo [ [(0,0), (0,1), (1,1), (1,0), (0,0)] ]
        point = makePointGeo (2.5, 0.5)
    (ensurePolygon $ envelope poly1) `shouldBe` env1
    (ensurePoint $ envelope point) `shouldBe` point
    (ensureMultiLineString $ boundary poly2) `shouldBe` env2
    convexHull poly2 `shouldBe` env3

  it "can use STRTrees" $ do
    let points = makePointGeo <$> [(0.1,0.1), (0.9, 0.9)]
        polygon = makePolygonGeo [[(0,0),(0,1),(1,1),(1,0),(0,0)]]
        tree = STR.fromList $ zip points [(0::Int)..]
        result = STR.lookup polygon tree 
    result `shouldBe` V.fromList [0,1]

  it "can run STRTrees on larger data" $ do
    points <- (fmap ensurePoint) <$> loadThingsFromFile "tests/sampledata/points.csv"
    polygons <- (fmap ensurePolygon) <$> loadThingsFromFile "tests/sampledata/polygons.csv"
    let tree = STR.fromList $ zip polygons [(0::Int)..]
    let results = fmap (\p -> STR.lookup p tree) $ take 5000 points
    let total = sum $ fmap sum results
    total `shouldBe` 45
