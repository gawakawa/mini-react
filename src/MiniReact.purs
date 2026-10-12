module MiniReact
  ( VirtualElement(..)
  , Prop(..)
  , Component
  , component
  , createDOM
  , updateDOM
  ) where

import Prelude

import Data.Array ((!!), length)
import Data.Foldable (for_)
import Data.Maybe (Maybe(..), isJust)
import Data.Traversable (for)
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
  | FunctionComponent Component

newtype Component = Component (forall r. (forall props. (props -> Effect VirtualElement) -> props -> r) -> r)

component :: forall props. (props -> Effect VirtualElement) -> props -> VirtualElement
component render props = FunctionComponent $ Component \k -> k render props

runComponent :: Component -> Effect VirtualElement
runComponent (Component c) = c \render props -> render props

sameComponent :: Component -> Component -> Boolean
sameComponent (Component a) (Component b) = a \ra _ -> b \rb _ -> unsafeRefEq ra rb

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

createFiber :: FiberRec -> Effect Fiber
createFiber rec = Fiber <$> Ref.new rec

readFiber :: Fiber -> Effect FiberRec
readFiber (Fiber ref) = Ref.read ref

modifyFiber :: Fiber -> (FiberRec -> FiberRec) -> Effect Unit
modifyFiber (Fiber ref) f = Ref.modify_ f ref

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

foreign import unsafeRefEq :: forall a b. a -> b -> Boolean

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
  FunctionComponent _ -> pure Nothing

reconcileChildren :: Fiber -> Array VirtualElement -> Effect Unit
reconcileChildren wip elements = do
  { alternate } <- readFiber wip
  oldChild <- case alternate of
    Nothing -> pure Nothing
    Just alt -> _.child <$> readFiber alt
  go 0 oldChild Nothing
  where
  go index oldFiber prevSibling =
    when (index < length elements || isJust oldFiber) do
      old <- for oldFiber \fiber -> { fiber, rec: _ } <$> readFiber fiber
      let
        element = elements !! index
        isSameType = case old, element of
          Just o, Just el -> sameType o.rec.vnode el
          _, _ -> false
      newFiber <- case old, element of
        Just o, Just el | isSameType -> Just <$> createFiber
          { vnode: el
          , dom: o.rec.dom
          , effectTag: Just Update
          , parent: Just wip
          , child: Nothing
          , sibling: Nothing
          , alternate: Just o.fiber
          }
        _, Just el -> Just <$> createFiber
          { vnode: el
          , dom: Nothing
          , effectTag: Just Placement
          , parent: Just wip
          , child: Nothing
          , sibling: Nothing
          , alternate: Nothing
          }
        _, Nothing -> pure Nothing
      unless isSameType $ for_ old \o -> Ref.modify_ (_ <> [ o.fiber ]) deletions
      if index == 0 then modifyFiber wip _ { child = newFiber }
      else for_ prevSibling \p -> modifyFiber p _ { sibling = newFiber }
      go (index + 1) (old >>= _.rec.sibling) newFiber

sameType :: VirtualElement -> VirtualElement -> Boolean
sameType = case _, _ of
  HostComponent a _ _, HostComponent b _ _ -> a == b
  HostText _, HostText _ -> true
  Fragment _, Fragment _ -> true
  FunctionComponent a, FunctionComponent b -> sameComponent a b
  _, _ -> false
