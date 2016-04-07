module Skybox where

import Task
import Signal

import WebGL exposing (..)


import Math.Vector2 exposing (Vec2, vec2)
import Math.Vector3 exposing (vec3, Vec3)
import Math.Vector3 exposing (..)
import Math.Matrix4 exposing (..)

skyTextures : Signal.Mailbox (List Texture)
skyTextures = Signal.mailbox []

getTextures =
  Task.sequence
      [ loadTextureWithFilter Linear "texture/miramar_lf.jpeg" -- left
      , loadTextureWithFilter Linear "texture/miramar_dn.jpeg" -- ignore
      , loadTextureWithFilter Linear "texture/miramar_ft.jpeg" -- front & good (flip?)
      , loadTextureWithFilter Linear "texture/miramar_bk.jpeg" -- back
      , loadTextureWithFilter Linear "texture/miramar_rt.jpeg" -- right & good (flip?)
      , loadTextureWithFilter Linear "texture/miramar_dn.jpeg" -- ignore
      ]
      `Task.andThen` (\tex -> Signal.send skyTextures.address tex)

zip = List.map2 (,)

cube : List Texture -> List (Texture, (Drawable Vertex))
cube textures =
  if List.length textures < 6 then []
  else
    let
      rft = vec3  1  1  1   -- right, front, top
      lft = vec3 -1  1  1   -- left,  front, top
      lbt = vec3 -1 -1  1
      rbt = vec3  1 -1  1
      rbb = vec3  1 -1 -1
      rfb = vec3  1  1 -1
      lfb = vec3 -1  1 -1
      lbb = vec3 -1 -1 -1

      tris = List.map Triangle
        [ face rft rfb rbb rbt   -- right
        , face rft rfb lfb lft   -- front (ignore)
        , face lft rft rbt lbt   -- top (actual front)
        , face rfb lfb lbb rbb   -- bottom
        , face lfb lft lbt lbb   -- left (actual right)
        , face rbt rbb lbb lbt   -- back
        ]
      in
        zip textures tris


face : Vec3 -> Vec3 -> Vec3 -> Vec3 -> List (Vertex, Vertex, Vertex)
face a b c d =
  let
    vertex position coord =
        Vertex position coord
  in
    [ (vertex a (vec2 0 0), vertex b (vec2 1.0 0), vertex c (vec2 1.0 1.0))
    , (vertex c (vec2 1.0 1.0), vertex d (vec2 0 1.0), vertex a (vec2 0 0))
    ]


type alias Vertex =
    { position : Vec3
    , coord : Vec2
    }

-- TODO - this is creating a buffer every frame!!
makeSkybox perspective textures =
  List.map2
    (\(tex, tris) ->
      (renderWithConfig
              []
              vertexShader
              fragmentShader
              tris
              { facetex = tex, perspective = perspective } ) )
    (cube textures)



vertexShader : Shader { attr | position:Vec3, coord: Vec2 }
                      {u | facetex: Texture, perspective: Mat4} { texcoord: Vec2}
vertexShader = [glsl|
precision mediump float;

attribute vec3 position;
attribute vec2 coord;
varying vec2 texcoord;
uniform mat4 perspective;
void main () {
    texcoord = vec2(coord.x, 1.0-coord.y);
    gl_Position = perspective * vec4(position * 160.0, 1.0);
}
|]


fragmentShader : Shader {} {u | facetex: Texture} { texcoord: Vec2 }
fragmentShader = [glsl|
precision mediump float;
uniform sampler2D facetex;
varying vec2 texcoord;

void main () {
    gl_FragColor = texture2D(facetex, texcoord);
}
|]
