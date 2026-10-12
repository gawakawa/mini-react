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
import Effect.Ref (Ref)
import Effect.Ref as Ref
import Effect.Unsafe (unsafePerformEffect)
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

data EffectTag = Update | Placement

newtype Fiber = Fiber (Ref FiberRec)

type FiberRec =
  { vnode :: VirtualElement
  , dom :: Maybe Node
  , effectTag :: Maybe EffectTag
  , parent :: Maybe Fiber
  , child :: Maybe Fiber
  , sibling :: Maybe Fiber
  , alternate :: Maybe Fiber
  }

wipRoot :: Ref (Maybe Fiber)
wipRoot = unsafePerformEffect $ Ref.new Nothing

currentRoot :: Ref (Maybe Fiber)
currentRoot = unsafePerformEffect $ Ref.new Nothing

nextUnitOfWork :: Ref (Maybe Fiber)
nextUnitOfWork = unsafePerformEffect $ Ref.new Nothing

deletions :: Ref (Array Fiber)
deletions = unsafePerformEffect $ Ref.new []

wipFiber :: Ref (Maybe Fiber)
wipFiber = unsafePerformEffect $ Ref.new Nothing

hookIndex :: Ref Int
hookIndex = unsafePerformEffect $ Ref.new 0

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
