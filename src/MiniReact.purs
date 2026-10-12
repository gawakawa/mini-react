module MiniReact
  ( VirtualElement(..)
  , Prop(..)
  , createDOM
  , updateDOM
  ) where

import Prelude

import Data.Foldable (for_)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Web.DOM.Document (Document, createElement, createTextNode)
import Web.DOM.Element (Element)
import Web.DOM.Element as Element
import Web.DOM.Node (Node)
import Web.DOM.Text as Text
import Web.Event.Event (EventType(..))
import Web.Event.EventTarget (EventListener, addEventListener, removeEventListener)
import Web.HTML (window)
import Web.HTML.HTMLDocument (toDocument)
import Web.HTML.Window (document)

data VirtualElement
  = HostComponent String (Array Prop) (Array VirtualElement)
  | HostText String
  | Fragment (Array VirtualElement)

data Prop
  = Property String String
  | Listener String EventListener

foreign import setProperty :: String -> String -> Element -> Effect Unit

getDocument :: Effect Document
getDocument = do
  w <- window
  toDocument <$> document w

updateDOM :: Element -> Array Prop -> Array Prop -> Effect Unit
updateDOM dom prevProps nextProps = do
  for_ prevProps case _ of
    Property key _ -> setProperty key "" dom
    Listener event l -> removeEventListener (EventType event) l false target
  for_ nextProps case _ of
    Property key value -> setProperty key value dom
    Listener event l -> addEventListener (EventType event) l false target
  where
  target = Element.toEventTarget dom

createDOM :: VirtualElement -> Effect (Maybe Node)
createDOM = case _ of
  HostComponent tag props _ -> do
    doc <- getDocument
    el <- createElement tag doc
    updateDOM el [] props
    pure $ Just $ Element.toNode el
  HostText text -> do
    doc <- getDocument
    t <- createTextNode text doc
    pure $ Just $ Text.toNode t
  Fragment _ -> pure Nothing
